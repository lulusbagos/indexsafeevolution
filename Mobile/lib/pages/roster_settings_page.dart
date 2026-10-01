import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/roster_model.dart';
import '../services/api.dart';

class RosterSettingsPage extends StatefulWidget {
  const RosterSettingsPage({super.key});

  @override
  State<RosterSettingsPage> createState() => _RosterSettingsPageState();
}

class _RosterSettingsPageState extends State<RosterSettingsPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Selected Tab: 0 = Reguler, 1 = Tugas
  int _selectedTab = 0;

  // Edit Mode
  int? _editingId;

  // Date Values - Reguler
  DateTime _awalDinas = DateTime.now();
  DateTime _akhirDinas = DateTime.now().add(const Duration(days: 42));
  DateTime _awalCuti = DateTime.now().add(const Duration(days: 43));
  DateTime _akhirCuti = DateTime.now().add(const Duration(days: 56));

  // Date Values - Tugas
  DateTime _awalTugas = DateTime.now();
  DateTime _akhirTugas = DateTime.now().add(const Duration(days: 30));
  final TextEditingController _keteranganTugasController =
      TextEditingController();

  // History & Summary Data
  List<RosterItem> _history = [];
  bool _isTugasExempt = false;
  int _computedOnsiteDays = 0;
  int _totalDaysInMonth = 30;
  double _ratio = 1.0;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _fetchRosterData();
  }

  @override
  void dispose() {
    _keteranganTugasController.dispose();
    super.dispose();
  }

  Future<void> _fetchRosterData() async {
    setState(() => _isLoading = true);
    final res = await _api.getRosterInfo();
    if (!mounted) return;

    res.fold(
      (err) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message'] ?? 'Gagal memuat data roster'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      },
      (data) {
        final info = RosterInfoResponse.fromJson(data);
        setState(() {
          _history = info.history;
          _isTugasExempt = info.isTugasExempt;
          _computedOnsiteDays = info.computedOnsiteDays;
          _totalDaysInMonth = info.totalDaysInMonth;
          _ratio = info.ratio;

          // Default initial fields if there's active/latest roster
          if (_editingId == null) {
            final target = info.activeRoster ?? info.latestRoster;
            if (target != null) {
              final isTugas = target['tipeRoster'] == 'TUGAS';
              if (isTugas) {
                _selectedTab = 1;
                _awalTugas = DateTime.tryParse(target['awalDinas'] ?? '') ??
                    DateTime.now();
                _akhirTugas = DateTime.tryParse(target['akhirDinas'] ?? '') ??
                    DateTime.now().add(const Duration(days: 30));
                _keteranganTugasController.text =
                    target['keterangan']?.toString() ?? '';
              } else {
                _selectedTab = 0;
                _awalDinas = DateTime.tryParse(target['awalDinas'] ?? '') ??
                    DateTime.now();
                _akhirDinas = DateTime.tryParse(target['akhirDinas'] ?? '') ??
                    DateTime.now().add(const Duration(days: 42));
                _awalCuti = DateTime.tryParse(target['awalCuti'] ?? '') ??
                    DateTime.now().add(const Duration(days: 43));
                _akhirCuti = DateTime.tryParse(target['akhirCuti'] ?? '') ??
                    DateTime.now().add(const Duration(days: 56));
              }
            }
          }

          _isLoading = false;
        });
      },
    );
  }

  void _startEdit(RosterItem item) {
    HapticFeedback.lightImpact();
    setState(() {
      _editingId = item.id;
      if (item.isTugas) {
        _selectedTab = 1;
        _awalTugas =
            DateTime.tryParse(item.awalDinas) ?? DateTime.now();
        _akhirTugas =
            DateTime.tryParse(item.akhirDinas) ?? DateTime.now().add(const Duration(days: 30));
        _keteranganTugasController.text = item.keterangan ?? '';
      } else {
        _selectedTab = 0;
        _awalDinas =
            DateTime.tryParse(item.awalDinas) ?? DateTime.now();
        _akhirDinas =
            DateTime.tryParse(item.akhirDinas) ?? DateTime.now().add(const Duration(days: 42));
        _awalCuti =
            DateTime.tryParse(item.awalCuti) ?? DateTime.now().add(const Duration(days: 43));
        _akhirCuti =
            DateTime.tryParse(item.akhirCuti) ?? DateTime.now().add(const Duration(days: 56));
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
    });
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required ValueChanged<DateTime> onDateSelected,
  }) async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7C3AED),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Future<void> _saveRoster() async {
    HapticFeedback.mediumImpact();

    if (_selectedTab == 1) {
      // Validasi Periode Tugas
      if (_awalTugas.isAfter(_akhirTugas)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tanggal mulai tugas tidak boleh setelah akhir tugas.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
    } else {
      // Validasi Roster Reguler
      if (_awalDinas.isAfter(_akhirDinas)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tanggal awal dinas tidak boleh setelah akhir dinas.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
      if (!_akhirDinas.isBefore(_awalCuti)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tanggal akhir dinas harus lebih awal dari awal cuti.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
      if (_awalCuti.isAfter(_akhirCuti)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tanggal awal cuti tidak boleh setelah akhir cuti.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final isTugas = _selectedTab == 1;
    final res = await _api.saveRoster(
      id: _editingId,
      tipeRoster: isTugas ? 'TUGAS' : 'REGULER',
      awalDinas: isTugas ? _dateFormat.format(_awalTugas) : _dateFormat.format(_awalDinas),
      akhirDinas: isTugas ? _dateFormat.format(_akhirTugas) : _dateFormat.format(_akhirDinas),
      awalCuti: isTugas ? _dateFormat.format(_akhirTugas) : _dateFormat.format(_awalCuti),
      akhirCuti: isTugas ? _dateFormat.format(_akhirTugas) : _dateFormat.format(_akhirCuti),
      keterangan: isTugas ? _keteranganTugasController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    res.fold(
      (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message'] ?? 'Gagal menyimpan pengaturan roster'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      },
      (successData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successData['message'] ?? 'Roster berhasil disimpan!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _editingId = null;
        _fetchRosterData();
      },
    );
  }

  Future<void> _deleteRosterItem(RosterItem item) async {
    HapticFeedback.lightImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Hapus Pengaturan?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data ${item.isTugas ? "Periode Tugas" : "Roster Reguler"} ini (${item.awalDinasFormatted} - ${item.akhirDinasFormatted})?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _api.deleteRoster(item.id);
    if (!mounted) return;

    res.fold(
      (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message'] ?? 'Gagal menghapus roster'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      },
      (data) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Pengaturan berhasil dihapus'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (_editingId == item.id) {
          _editingId = null;
        }
        _fetchRosterData();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Will inform parent page that changes may have occurred
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: const Text(
            'Pengaturan Roster & Tugas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7C3AED)),
              tooltip: 'Muat Ulang',
              onPressed: _fetchRosterData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7C3AED),
                  strokeWidth: 3,
                ),
              )
            : RefreshIndicator(
                color: const Color(0xFF7C3AED),
                onRefresh: _fetchRosterData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status SAP Banner Card
                      _buildTargetStatusCard(),

                      const SizedBox(height: 18),

                      // Edit mode banner if editing
                      if (_editingId != null) _buildEditModeBanner(),

                      // Tab Switcher (Roster Reguler vs Periode Tugas)
                      _buildTabSwitcher(),

                      const SizedBox(height: 18),

                      // Form Sections
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _selectedTab == 0
                            ? _buildRegulerForm()
                            : _buildTugasForm(),
                      ),

                      const SizedBox(height: 18),

                      // Save Button
                      _buildSaveButton(),

                      const SizedBox(height: 28),

                      // History Section
                      _buildHistorySection(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // Target Status Info Card
  Widget _buildTargetStatusCard() {
    final percent = (_ratio * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isTugasExempt
              ? [const Color(0xFF059669), const Color(0xFF10B981)]
              : [const Color(0xFF6D28D9), const Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_isTugasExempt ? const Color(0xFF10B981) : const Color(0xFF7C3AED))
                .withValues(alpha: 0.3),
            blurRadius: 14,
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isTugasExempt
                          ? Icons.verified_rounded
                          : Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isTugasExempt ? 'BEBAS TARGET SAP' : 'STATUS ON-SITE SAP',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Bulan Ini: ${_displayFormat.format(DateTime.now()).substring(3)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isTugasExempt
                ? 'Target SAP Ditiadakan (0 Target)'
                : '$_computedOnsiteDays Hari On-Site / $_totalDaysInMonth Hari (Proporsi: $percent%)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isTugasExempt
                ? 'Anda saat ini tercatat dalam periode tugas khusus sehingga target kepatuhan K3 disesuaikan menjadi 0.'
                : 'Target laporan inspeksi, hazard, observasi dll. diskalakan proporsional terhadap jadwal onsite aktif Anda.',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Edit Mode Notification Banner
  Widget _buildEditModeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Mode Edit Aktif: Mengubah riwayat pengaturan yang dipilih',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
              ),
            ),
          ),
          TextButton(
            onPressed: _cancelEdit,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab Switcher
  Widget _buildTabSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = 0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.work_rounded,
                      size: 16,
                      color: _selectedTab == 0
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Roster Reguler',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _selectedTab == 0
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF64748B),
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
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = 1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.flight_takeoff_rounded,
                      size: 16,
                      color: _selectedTab == 1
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Periode Tugas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _selectedTab == 1
                            ? const Color(0xFF0284C7)
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
    );
  }

  // Form Roster Reguler
  Widget _buildRegulerForm() {
    final hariDinas = _akhirDinas.difference(_awalDinas).inDays + 1;
    final hariCuti = _akhirCuti.difference(_awalCuti).inDays + 1;

    return Column(
      key: const ValueKey('reguler_form'),
      children: [
        // Card Dinas (Onsite)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Color(0xFF7C3AED), size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Periode Dinas (On-Site)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$hariDinas Hari Dinas',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildDatePickerField(
                      label: 'Mulai Dinas',
                      dateValue: _awalDinas,
                      onTap: () => _pickDate(
                        context: context,
                        initialDate: _awalDinas,
                        onDateSelected: (d) => setState(() => _awalDinas = d),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDatePickerField(
                      label: 'Akhir Dinas',
                      dateValue: _akhirDinas,
                      onTap: () => _pickDate(
                        context: context,
                        initialDate: _akhirDinas,
                        onDateSelected: (d) => setState(() => _akhirDinas = d),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Card Cuti (Offsite)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.beach_access_rounded,
                        color: Color(0xFFEA580C), size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Periode Roster (Cuti Offsite)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$hariCuti Hari Cuti',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildDatePickerField(
                      label: 'Mulai Cuti',
                      dateValue: _awalCuti,
                      onTap: () => _pickDate(
                        context: context,
                        initialDate: _awalCuti,
                        onDateSelected: (d) => setState(() => _awalCuti = d),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDatePickerField(
                      label: 'Akhir Cuti',
                      dateValue: _akhirCuti,
                      onTap: () => _pickDate(
                        context: context,
                        initialDate: _akhirCuti,
                        onDateSelected: (d) => setState(() => _akhirCuti = d),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Info Note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 15, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Target K3 bulanan wajib dipenuhi secara proporsional sesuai hari dinas aktif. Saat cuti, target ditiadakan.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Form Periode Tugas
  Widget _buildTugasForm() {
    final hariTugas = _akhirTugas.difference(_awalTugas).inDays + 1;

    return Column(
      key: const ValueKey('tugas_form'),
      children: [
        // Free Target Highlight Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFECFDF5), Color(0xFFE0F2FE)],
            ),
            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BEBAS SAP: TARGET = 0',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF047857),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Selama masa penugasan di luar site, Anda tidak dikenakan kewajiban target laporan K3 bulanan.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF065F46),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Jadwal Tugas Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.date_range_rounded,
                        color: Color(0xFF0284C7), size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Jadwal & Keterangan Tugas',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$hariTugas Hari Tugas',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildDatePickerField(
                      label: 'Mulai Tugas',
                      dateValue: _awalTugas,
                      onTap: () => _pickDate(
                        context: context,
                        initialDate: _awalTugas,
                        onDateSelected: (d) => setState(() => _awalTugas = d),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDatePickerField(
                      label: 'Akhir Tugas',
                      dateValue: _akhirTugas,
                      onTap: () => _pickDate(
                        context: context,
                        initialDate: _akhirTugas,
                        onDateSelected: (d) => setState(() => _akhirTugas = d),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Keterangan / Keperluan Penugasan',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _keteranganTugasController,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Contoh: Tugas HO / Diklat Luar / Audit Vendor',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper Date Picker Widget
  Widget _buildDatePickerField({
    required String label,
    required DateTime dateValue,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 16, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _displayFormat.format(dateValue),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Save Button
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        onPressed: _isSaving ? null : _saveRoster,
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                _editingId != null ? 'Perbarui Pengaturan' : 'Simpan Pengaturan Roster',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  // Riwayat Pengaturan Section
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RIWAYAT PENGATURAN ROSTER',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${_history.length} entri',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Icon(Icons.history_rounded, size: 36, color: Color(0xFFCBD5E1)),
                SizedBox(height: 8),
                Text(
                  'Belum ada riwayat pengaturan roster',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _history[index];
              final isTugas = item.isTugas;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _editingId == item.id
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFE2E8F0),
                    width: _editingId == item.id ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isTugas
                                ? const Color(0xFFE0F2FE)
                                : const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isTugas
                                  ? const Color(0xFFBAE6FD)
                                  : const Color(0xFFE9D5FF),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isTugas
                                    ? Icons.flight_takeoff_rounded
                                    : Icons.work_rounded,
                                size: 11,
                                color: isTugas
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF7C3AED),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isTugas ? 'Periode Tugas' : 'Roster Reguler',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isTugas
                                      ? const Color(0xFF0284C7)
                                      : const Color(0xFF7C3AED),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.status.contains('Aktif') ||
                                    item.status.contains('Dinas')
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: item.status.contains('Aktif') ||
                                      item.status.contains('Dinas')
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Action buttons
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: Color(0xFF0284C7)),
                          tooltip: 'Edit',
                          onPressed: () => _startEdit(item),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: Color(0xFFDC2626)),
                          tooltip: 'Hapus',
                          onPressed: () => _deleteRosterItem(item),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (isTugas) ...[
                      Text(
                        '${item.awalDinasFormatted} - ${item.akhirDinasFormatted}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.hariDinas} hari penugasan • ${item.keterangan?.isNotEmpty == true ? item.keterangan : "Bebas target SAP"}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dinas (Onsite)',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF7C3AED)),
                                ),
                                Text(
                                  '${item.awalDinasFormatted} - ${item.akhirDinasFormatted}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '${item.hariDinas} hari onsite',
                                  style: const TextStyle(
                                      fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cuti (Offsite)',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEA580C)),
                                ),
                                Text(
                                  '${item.awalCutiFormatted} - ${item.akhirCutiFormatted}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '${item.hariCuti} hari cuti',
                                  style: const TextStyle(
                                      fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Disimpan pada: ${item.createdAt}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

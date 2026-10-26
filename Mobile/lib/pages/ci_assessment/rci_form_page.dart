import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/sap_form_widgets.dart';
import 'rci_model.dart';

class _EmployeeOption {
  final String nik;
  final String nama;
  final String jabatan;
  final String departemen;
  final String perusahaan;
  final int? perusahaanId;
  final String? foto;
  final bool isPrimary;

  _EmployeeOption({
    required this.nik,
    required this.nama,
    required this.jabatan,
    this.departemen = '',
    required this.perusahaan,
    this.perusahaanId,
    this.foto,
    this.isPrimary = false,
  });

  String get displayName => '$nama ($nik)';
}

class _EmployeeAvatar extends StatefulWidget {
  final String? photo;
  final String name;
  final String nik;
  final double radius;
  final Color? fallbackBg;
  final Color? fallbackFg;

  const _EmployeeAvatar({
    required this.photo,
    required this.name,
    required this.nik,
    this.radius = 18,
    this.fallbackBg,
    this.fallbackFg,
  });

  @override
  State<_EmployeeAvatar> createState() => _EmployeeAvatarState();
}

class _EmployeeAvatarState extends State<_EmployeeAvatar> {
  int _attempt = 0;

  String? _getUrl(int attempt) {
    final baseUrl = ApiService().baseUrl;
    final photo = widget.photo?.trim();
    if (attempt == 0) {
      if (photo != null && photo.isNotEmpty) {
        if (photo.startsWith('http://') || photo.startsWith('https://')) return photo;
        if (photo.startsWith('/uploads/') || photo.startsWith('/')) return '$baseUrl$photo';
        return '$baseUrl/api/image/${Uri.encodeComponent(photo)}';
      }
      if (widget.nik.isNotEmpty) {
        return '$baseUrl/api/image/${Uri.encodeComponent(widget.nik)}.jpg';
      }
      return null;
    } else if (attempt == 1) {
      if (widget.nik.isNotEmpty && photo != '${widget.nik}.jpg') {
        return '$baseUrl/api/image/${Uri.encodeComponent(widget.nik)}.jpg';
      }
      return null;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant _EmployeeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo || oldWidget.nik != widget.nik) {
      _attempt = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.trim().isNotEmpty ? widget.name.trim()[0].toUpperCase() : 'U';
    final bg = widget.fallbackBg ?? const Color(0xFFE0F2FE);
    final fg = widget.fallbackFg ?? const Color(0xFF0284C7);

    final url = _getUrl(_attempt);
    if (url == null || _attempt >= 2) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bg,
        child: Text(
          initial,
          style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: widget.radius * 0.85),
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: widget.radius * 2,
        height: widget.radius * 2,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _attempt < 2) {
                setState(() => _attempt++);
              }
            });
            return CircleAvatar(
              radius: widget.radius,
              backgroundColor: bg,
              child: Text(
                initial,
                style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: widget.radius * 0.85),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return CircleAvatar(
              radius: widget.radius,
              backgroundColor: bg,
              child: Text(
                initial,
                style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: widget.radius * 0.85),
              ),
            );
          },
        ),
      ),
    );
  }
}

class RciFormPage extends StatefulWidget {
  final RciReportItem? editItem;

  const RciFormPage({super.key, this.editItem});

  @override
  State<RciFormPage> createState() => _RciFormPageState();
}

class _RciFormPageState extends State<RciFormPage> {
  final _api = ApiService();
  final _db = DatabaseService();
  final _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();

  // Section 1 Controllers
  late DateTime _tanggal;
  late TimeOfDay _waktu;
  final _areaCtrl = TextEditingController();
  final _detilLokasiCtrl = TextEditingController();
  final _namaJalanCtrl = TextEditingController();
  final _segmentJalanCtrl = TextEditingController();
  final _lokasiCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  String _shift = 'Shift 1 (Siang)';

  // Section 1.b Team Signers
  final List<_EmployeeOption> _selectedCreators = [];
  final List<_EmployeeOption> _selectedApprovers = [];

  // Section 2 Controllers
  final _panjangSegmentCtrl = TextEditingController(text: '100');

  // 8 Deficits Controllers
  final _defSurfacingCtrl = TextEditingController(text: '0');
  final _defUndulationCtrl = TextEditingController(text: '0');
  final _defSpoilCtrl = TextEditingController(text: '0');
  final _defSafetyBermCtrl = TextEditingController(text: '0');
  final _defRoadAttachmentCtrl = TextEditingController(text: '0');
  final _defDustCtrl = TextEditingController(text: '0');
  final _defCrossfallCtrl = TextEditingController(text: '0');
  final _defDrainageCtrl = TextEditingController(text: '0');

  // 8 Scores (Scale 2.0 - 4.0)
  double _skorSurfacing = 4.0;
  double _skorUndulation = 4.0;
  double _skorSpoil = 4.0;
  double _skorSafetyBerm = 4.0;
  double _skorRoadAttachment = 4.0;
  double _skorDust = 4.0;
  double _skorCrossfall = 4.0;
  double _skorDrainage = 4.0;

  // Section 3 Controllers
  final _catatanCtrl = TextEditingController();
  final _tindakanCtrl = TextEditingController();
  final _picCtrl = TextEditingController();
  _EmployeeOption? _selectedPicEmployee;
  File? _fotoFile;
  String? _existingFotoUrl;

  bool _isSaving = false;

  // Master Areas
  final List<String> _masterAreas = [
    'Port/Jetty - Indexim',
    'CPP-33 & ROM - Indexim',
    'Kantor - Indexim',
    'Mess & Fasilitas - Indexim',
    'Nursery - Indexim',
    'Hauling Road - Indexim',
    'Workshop - Indexim',
    'Water Treatment - Indexim',
    'PIT - MGE',
    'PIT - KPP',
    'PIT - GPE',
    'Disposal - Indexim',
    'Disposal - KPP',
    'Disposal - MGE',
  ];

  static const _blueColor = Color(0xFF1D4ED8);
  static const _emeraldColor = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    final now = DateTime.now();
    _tanggal = widget.editItem?.tanggal ?? now;
    _waktu = widget.editItem != null
        ? TimeOfDay(
            hour: int.tryParse(widget.editItem!.waktu.split(':').first) ?? now.hour,
            minute: int.tryParse(widget.editItem!.waktu.split(':').last) ?? now.minute,
          )
        : TimeOfDay.now();

    final item = widget.editItem;
    if (item != null) {
      _areaCtrl.text = item.area;
      _detilLokasiCtrl.text = item.detilLokasi ?? '';
      _namaJalanCtrl.text = item.namaJalan ?? '';
      _segmentJalanCtrl.text = item.segmentJalan ?? '';
      _lokasiCtrl.text = item.lokasi;
      _shift = item.shift ?? 'Shift 1 (Siang)';
      _latCtrl.text = item.latitude ?? '';
      _lngCtrl.text = item.longitude ?? '';
      _panjangSegmentCtrl.text = (item.panjangSegment ?? 100).toStringAsFixed(0);

      _defSurfacingCtrl.text = item.defisitSurfacing.toStringAsFixed(0);
      _defUndulationCtrl.text = item.defisitUndulation.toStringAsFixed(0);
      _defSpoilCtrl.text = item.defisitSpoil.toStringAsFixed(0);
      _defSafetyBermCtrl.text = item.defisitSafetyBerm.toStringAsFixed(0);
      _defRoadAttachmentCtrl.text = item.defisitRoadAttachment.toStringAsFixed(0);
      _defDustCtrl.text = item.defisitDust.toStringAsFixed(0);
      _defCrossfallCtrl.text = item.defisitCrossfall.toStringAsFixed(0);
      _defDrainageCtrl.text = item.defisitDrainage.toStringAsFixed(0);

      _skorSurfacing = item.skorSurfacing;
      _skorUndulation = item.skorUndulation;
      _skorSpoil = item.skorSpoil;
      _skorSafetyBerm = item.skorSafetyBerm;
      _skorRoadAttachment = item.skorRoadAttachment;
      _skorDust = item.skorDust;
      _skorCrossfall = item.skorCrossfall;
      _skorDrainage = item.skorDrainage;

      _catatanCtrl.text = item.catatan ?? '';
      _tindakanCtrl.text = item.tindakanPerbaikan ?? '';
      _picCtrl.text = item.pic ?? '';
      _existingFotoUrl = item.fotoUrl;

      // Populate members
      for (final m in item.members) {
        final opt = _EmployeeOption(
          nik: m.nik,
          nama: m.nama,
          jabatan: m.jabatan ?? 'Staff',
          departemen: '',
          perusahaan: m.perusahaan ?? 'PT MEGA GLOBAL ENERGY',
          perusahaanId: m.perusahaanId,
          isPrimary: m.role == 'Creator' && m.nik == item.nik,
        );
        if (m.role == 'Creator') {
          _selectedCreators.add(opt);
        } else if (m.role == 'Approver') {
          _selectedApprovers.add(opt);
        }
      }
    } else {
      // Auto-assign current user as primary Creator
      final profile = PreferenceService.getProfile();
      final nik = profile?.noNik ?? PreferenceService.getUser() ?? '';
      final nama = profile?.namaLengkap ?? '';
      final jabatan = profile?.depart ?? 'Staff';
      final perusahaan = profile?.company ?? 'PT MEGA GLOBAL ENERGY';
      final perusahaanId = profile?.companyId;

      _selectedCreators.add(_EmployeeOption(
        nik: nik,
        nama: nama.isNotEmpty ? nama : nik,
        jabatan: jabatan,
        departemen: profile?.depart ?? '',
        perusahaan: perusahaan,
        perusahaanId: perusahaanId,
        isPrimary: true,
      ));
    }

    _loadLocalAreas();
  }

  Future<void> _loadLocalAreas() async {
    try {
      final sqldb = await _db.database;
      final local = await sqldb.rawQuery(
        "SELECT DISTINCT area_utama FROM tbl_m_benchmark WHERE area_utama IS NOT NULL AND area_utama != '' ORDER BY area_utama",
      );
      if (local.isNotEmpty && mounted) {
        setState(() {
          final list = local.map((e) => e['area_utama'].toString().trim()).toList();
          for (final a in list) {
            if (!_masterAreas.contains(a)) _masterAreas.add(a);
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _detilLokasiCtrl.dispose();
    _namaJalanCtrl.dispose();
    _segmentJalanCtrl.dispose();
    _lokasiCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _panjangSegmentCtrl.dispose();
    _defSurfacingCtrl.dispose();
    _defUndulationCtrl.dispose();
    _defSpoilCtrl.dispose();
    _defSafetyBermCtrl.dispose();
    _defRoadAttachmentCtrl.dispose();
    _defDustCtrl.dispose();
    _defCrossfallCtrl.dispose();
    _defDrainageCtrl.dispose();
    _catatanCtrl.dispose();
    _tindakanCtrl.dispose();
    _picCtrl.dispose();
    super.dispose();
  }

  // ==================== Calculations ====================
  double get _panjangSegmenVal => double.tryParse(_panjangSegmentCtrl.text) ?? 100.0;

  double get _skorPermukaanGroup {
    return ((_skorSurfacing * 0.20) + (_skorUndulation * 0.35) + (_skorSpoil * 0.05)) / 0.60;
  }

  double get _skorSafetyBermGroup {
    return ((_skorSafetyBerm * 0.10) + (_skorRoadAttachment * 0.05) + (_skorDust * 0.05)) / 0.20;
  }

  double get _skorDrainageGroup {
    return ((_skorCrossfall * 0.10) + (_skorDrainage * 0.10)) / 0.20;
  }

  double get _actualRoadScore {
    final s = (_skorPermukaanGroup * 0.60) + (_skorSafetyBermGroup * 0.20) + (_skorDrainageGroup * 0.20);
    return double.parse(s.toStringAsFixed(2));
  }

  double get _achievement {
    final ach = (_actualRoadScore / 4.0) * 100.0;
    return double.parse(ach.toStringAsFixed(1));
  }

  String get _kategoriIndex {
    if (_achievement >= 85 || _actualRoadScore >= 3.6) return 'Baik';
    if (_achievement >= 70 || _actualRoadScore >= 3.0) return 'Sedang';
    return 'Kurang';
  }

  Color get _scoreColor {
    if (_achievement >= 85 || _actualRoadScore >= 3.6) return _emeraldColor;
    if (_achievement >= 70 || _actualRoadScore >= 3.0) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  void _onDeficitChanged(String param, String val) {
    final def = double.tryParse(val) ?? 0.0;
    final totalLen = _panjangSegmenVal > 0 ? _panjangSegmenVal : 100.0;
    final pctDef = (def / totalLen) * 100.0;

    double newScore = 4.0;
    if (def == 0) {
      newScore = 4.0;
    } else if (pctDef <= 10.0) {
      newScore = 3.5;
    } else if (pctDef <= 20.0) {
      newScore = 3.0;
    } else if (pctDef <= 50.0) {
      newScore = 2.5;
    } else {
      newScore = 2.0;
    }

    setState(() {
      switch (param) {
        case 'Surfacing':
          _skorSurfacing = newScore;
          break;
        case 'Undulation':
          _skorUndulation = newScore;
          break;
        case 'Spoil':
          _skorSpoil = newScore;
          break;
        case 'SafetyBerm':
          _skorSafetyBerm = newScore;
          break;
        case 'RoadAttachment':
          _skorRoadAttachment = newScore;
          break;
        case 'Dust':
          _skorDust = newScore;
          break;
        case 'Crossfall':
          _skorCrossfall = newScore;
          break;
        case 'Drainage':
          _skorDrainage = newScore;
          break;
      }
    });
  }

  void _onManualScoreTapped(String param, double score) {
    final totalLen = _panjangSegmenVal > 0 ? _panjangSegmenVal : 100.0;
    double proportionalDef = 0.0;
    if (score == 3.5) proportionalDef = (totalLen * 0.05).roundToDouble();
    if (score == 3.0) proportionalDef = (totalLen * 0.15).roundToDouble();
    if (score == 2.5) proportionalDef = (totalLen * 0.30).roundToDouble();
    if (score == 2.0) proportionalDef = (totalLen * 0.60).roundToDouble();

    setState(() {
      switch (param) {
        case 'Surfacing':
          _skorSurfacing = score;
          _defSurfacingCtrl.text = proportionalDef.toStringAsFixed(0);
          break;
        case 'Undulation':
          _skorUndulation = score;
          _defUndulationCtrl.text = proportionalDef.toStringAsFixed(0);
          break;
        case 'Spoil':
          _skorSpoil = score;
          _defSpoilCtrl.text = proportionalDef.toStringAsFixed(0);
          break;
        case 'SafetyBerm':
          _skorSafetyBerm = score;
          _defSafetyBermCtrl.text = proportionalDef.toStringAsFixed(0);
          break;
        case 'RoadAttachment':
          _skorRoadAttachment = score;
          _defRoadAttachmentCtrl.text = proportionalDef.toStringAsFixed(0);
          break;
        case 'Dust':
          _skorDust = score;
          _defDustCtrl.text = proportionalDef.toStringAsFixed(0);
          break;
        case 'Crossfall':
          _skorCrossfall = score;
          _defCrossfallCtrl.text = proportionalDef.toStringAsFixed(0);
          break;
        case 'Drainage':
          _skorDrainage = score;
          _defDrainageCtrl.text = proportionalDef.toStringAsFixed(0);
          break;
      }
    });
  }

  // ==================== Auto Recommendation ====================
  String _generateAutoRecommendation() {
    final actions = <String>[];
    if (_skorSurfacing < 4.0) {
      if (_skorSurfacing <= 2.5) {
        actions.add('URGENT: Re-sheeting batu split lapis aus & pemadatan compactor');
      } else {
        actions.add('Scraping ringan & penambahan batu split tipis');
      }
    }
    if (_skorUndulation < 4.0) {
      if (_skorUndulation <= 2.5) {
        actions.add('URGENT: Grading mendalam menghilangkan lendutan keriting');
      } else {
        actions.add('Perataan gelombang jalan dengan motor grader');
      }
    }
    if (_skorSpoil < 4.0) {
      if (_skorSpoil <= 2.5) {
        actions.add('URGENT: Singkirkan tumpukan spoil / batubara penyempitan');
      } else {
        actions.add('Pembersihan ceceran spoil & pelebaran jalan ke 18m');
      }
    }
    if (_skorSafetyBerm < 4.0) {
      if (_skorSafetyBerm <= 2.5) {
        actions.add('URGENT: Peninggian tanggul pengaman minimum 3/4 tinggi ban');
      } else {
        actions.add('Perapihan tanggul pengaman & pembersihan gulma');
      }
    }
    if (_skorRoadAttachment < 4.0) {
      actions.add('Lengkapi & perbaiki rambu serta delineator per 35m');
    }
    if (_skorDust < 4.0) {
      actions.add('Tingkatkan ritasi penyiraman water truck');
    }
    if (_skorCrossfall < 4.0) {
      actions.add('Bentuk crossfall kemiringan 0.5% - 1% untuk penirisan');
    }
    if (_skorDrainage < 4.0) {
      if (_skorDrainage <= 2.5) {
        actions.add('URGENT: Penggalian kembali parit tersumbat / buat sodetan');
      } else {
        actions.add('Pembersihan endapan sedimentasi parit drainase');
      }
    }

    if (actions.isEmpty) {
      return 'Pertahankan pemeliharaan rutin jalan angkut.';
    }
    return '${actions.join('; ')}.';
  }

  void _applyAutoRecommendation() {
    final rec = _generateAutoRecommendation();
    setState(() {
      _tindakanCtrl.text = rec;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rekomendasi otomatis disalin ke Form Tindakan Perbaikan!')),
    );
  }

  // ==================== Image Picker ====================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (picked != null) {
        setState(() {
          _fotoFile = File(picked.path);
        });
      }
    } catch (e) {
      _showSnack('Gagal memilih foto: $e');
    }
  }

  // ==================== Target SAP Employee Picker Modal ====================
  Future<_EmployeeOption?> _openEmployeePicker({
    required String title,
    required String subtitle,
    Color themeColor = _blueColor,
  }) {
    return showModalBottomSheet<_EmployeeOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RciEmployeePickerSheet(
        title: title,
        subtitle: subtitle,
        themeColor: themeColor,
      ),
    );
  }

  void _addCreator() async {
    final emp = await _openEmployeePicker(
      title: 'Pilih Rekan Tim Sidak',
      subtitle: 'Pilih rekan tim sidak',
      themeColor: _blueColor,
    );
    if (emp != null && mounted) {
      if (!_selectedCreators.any((x) => x.nik == emp.nik)) {
        setState(() => _selectedCreators.add(emp));
      } else {
        _showSnack('${emp.nama} sudah ada di daftar tim sidak.');
      }
    }
  }

  void _addApprover() async {
    final emp = await _openEmployeePicker(
      title: 'Pilih Penyetuju (Approver)',
      subtitle: 'Wajib minimal 1 atasan / perwakilan',
      themeColor: _emeraldColor,
    );
    if (emp != null && mounted) {
      if (!_selectedApprovers.any((x) => x.nik == emp.nik)) {
        setState(() => _selectedApprovers.add(emp));
      } else {
        _showSnack('${emp.nama} sudah ada di daftar penyetuju.');
      }
    }
  }

  void _choosePic() async {
    final emp = await _openEmployeePicker(
      title: 'Pilih PIC',
      subtitle: 'Pilih penanggung jawab tindakan',
      themeColor: const Color(0xFF0D5C75),
    );
    if (emp != null && mounted) {
      setState(() {
        _selectedPicEmployee = emp;
        _picCtrl.text = '${emp.nama} (${emp.nik})';
      });
    }
  }

  // ==================== Submit ====================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack('Lengkapi field yang wajib diisi.');
      return;
    }

    if (_areaCtrl.text.trim().isEmpty) {
      _showSnack('Area Utama wajib dipilih.');
      return;
    }

    if (_namaJalanCtrl.text.trim().isEmpty) {
      _showSnack('Nama Jalan / Jalur Hauling wajib diisi.');
      return;
    }

    // MANDATORY APPROVER VALIDATION!
    if (_selectedApprovers.isEmpty) {
      _showApproverRequiredDialog();
      return;
    }

    // Anti-Backdate Validation
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reportDate = DateTime(_tanggal.year, _tanggal.month, _tanggal.day);

    if (widget.editItem == null && reportDate.isBefore(today)) {
      _showSnack('Tanggal inspeksi tidak boleh backdate (kurang dari hari ini).');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = PreferenceService.getProfile();
      final userNik = profile?.noNik ?? PreferenceService.getUser() ?? '';
      final userName = profile?.namaLengkap ?? '';
      final userDept = profile?.depart ?? 'Staff';
      final userCompany = profile?.company ?? 'PT MEGA GLOBAL ENERGY';
      final userCompanyId = profile?.companyId ?? 0;
      final waktuStr = '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}';

      final creatorNiks = _selectedCreators.map((e) => e.nik).toList();
      final approverNiks = _selectedApprovers.map((e) => e.nik).toList();

      final resolvedLokasi = _lokasiCtrl.text.trim().isNotEmpty
          ? _lokasiCtrl.text.trim()
          : (_latCtrl.text.trim().isNotEmpty
              ? 'GPS: ${_latCtrl.text.trim()}, ${_lngCtrl.text.trim()}'
              : _namaJalanCtrl.text.trim());

      final map = <String, dynamic>{
        if (widget.editItem != null) 'id': widget.editItem!.id,
        'tanggal': DateFormat('yyyy-MM-dd').format(_tanggal),
        'waktu': waktuStr,
        'area': _areaCtrl.text.trim(),
        'detil_lokasi': _detilLokasiCtrl.text.trim(),
        'detilLokasi': _detilLokasiCtrl.text.trim(),
        'nama_jalan': _namaJalanCtrl.text.trim(),
        'namaJalan': _namaJalanCtrl.text.trim(),
        'segment_jalan': _segmentJalanCtrl.text.trim(),
        'segmentJalan': _segmentJalanCtrl.text.trim(),
        'lokasi': resolvedLokasi,
        'shift': _shift,
        'latitude': _latCtrl.text.trim(),
        'longitude': _lngCtrl.text.trim(),
        'panjang_segment': _panjangSegmenVal,
        'panjangSegment': _panjangSegmenVal,

        // 8 Deficits
        'defisit_surfacing': double.tryParse(_defSurfacingCtrl.text) ?? 0.0,
        'defisit_undulation': double.tryParse(_defUndulationCtrl.text) ?? 0.0,
        'defisit_spoil': double.tryParse(_defSpoilCtrl.text) ?? 0.0,
        'defisit_safety_berm': double.tryParse(_defSafetyBermCtrl.text) ?? 0.0,
        'defisit_road_attachment': double.tryParse(_defRoadAttachmentCtrl.text) ?? 0.0,
        'defisit_dust': double.tryParse(_defDustCtrl.text) ?? 0.0,
        'defisit_crossfall': double.tryParse(_defCrossfallCtrl.text) ?? 0.0,
        'defisit_drainage': double.tryParse(_defDrainageCtrl.text) ?? 0.0,

        // 8 Scores
        'skor_surfacing': _skorSurfacing,
        'skor_undulation': _skorUndulation,
        'skor_spoil': _skorSpoil,
        'skor_safety_berm': _skorSafetyBerm,
        'skor_road_attachment': _skorRoadAttachment,
        'skor_dust': _skorDust,
        'skor_crossfall': _skorCrossfall,
        'skor_drainage': _skorDrainage,

        // 3 Pillars
        'skor_permukaan_group': _skorPermukaanGroup,
        'skor_safety_berm_group': _skorSafetyBermGroup,
        'skor_drainage_group': _skorDrainageGroup,

        // Actual Scores & Achievement
        'actual_road_score': _actualRoadScore,
        'achievement': _achievement,
        'total_score': _achievement,
        'kategori_index': _kategoriIndex,

        'catatan': _catatanCtrl.text.trim(),
        'tindakan_perbaikan': _tindakanCtrl.text.trim(),
        'pic': _picCtrl.text.trim(),

        'nik': userNik,
        'nama': userName,
        'departemen': userDept,
        'perusahaan': userCompany,
        'perusahaan_id': userCompanyId,

        // Signatures Lists
        'creatorNiks': creatorNiks,
        'approverNiks': approverNiks,
      };

      final cleanMap = Map<String, dynamic>.from(map);
      bool isSavedOnline = false;

      try {
        if (_fotoFile != null) {
          final filename = _fotoFile!.path.split(Platform.pathSeparator).last;
          map['foto'] = await MultipartFile.fromFile(_fotoFile!.path, filename: filename);
        }
        final formData = FormData.fromMap(map);
        final res = await _api.saveRciReport(formData);
        res.fold(
          (err) => isSavedOnline = false,
          (_) => isSavedOnline = true,
        );
      } catch (_) {
        isSavedOnline = false;
      }

      if (!isSavedOnline) {
        final localId = 'rci_${DateTime.now().millisecondsSinceEpoch}';
        await OfflineSyncService.instance.enqueue(
          feature: 'rci',
          localId: localId,
          payload: {
            'map': cleanMap,
            if (_fotoFile != null) 'photoPath': _fotoFile!.path,
          },
        );
      }

      setState(() => _isSaving = false);

      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  isSavedOnline ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                  color: isSavedOnline ? _emeraldColor : const Color(0xFFF59E0B),
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(isSavedOnline ? 'Berhasil Disimpan!' : 'Disimpan Offline'),
              ],
            ),
            content: Text(
              isSavedOnline
                  ? (widget.editItem != null
                      ? 'Laporan RCI berhasil diperbarui di server.'
                      : 'Laporan RCI baru berhasil disimpan dan dikirimkan ke Penyetuju.')
                  : 'Laporan RCI tersimpan di perangkat (Mode Offline) dan akan disinkronkan otomatis saat ada koneksi.',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blueColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Selesai'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Terjadi kesalahan: $e');
    }
  }

  void _showApproverRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Approver Belum Dipilih!'),
          ],
        ),
        content: const Text(
          'Standar Berita Acara SP3 mewajibkan minimal 1 orang atasan / perwakilan penyetuju (Approver).\n\nSilakan ketuk tombol "+ Tambah Penyetuju" di Section 1.B.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _emeraldColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _addApprover();
            },
            child: const Text('Pilih Penyetuju Sekarang'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? _emeraldColor : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: TopBar(
        title: widget.editItem != null ? 'Edit Inspeksi RCI' : 'Form Penilaian RCI',
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _blueColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          icon: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save_rounded),
          label: Text(
            _isSaving ? 'Menyimpan...' : 'Simpan Penilaian RCI',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          onPressed: _isSaving ? null : _submit,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ================= SECTION 1: IDENTITAS LOKASI =================
            _sectionHeader('1. Identitas Lokasi & Segmen Jalan', Icons.place_rounded, _blueColor),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _boxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tanggal & Waktu in a clean 2-column row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final minDate = DateTime(now.year, now.month, now.day);
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _tanggal.isBefore(minDate) ? minDate : _tanggal,
                              firstDate: minDate,
                              lastDate: DateTime(now.year + 2),
                            );
                            if (picked != null) setState(() => _tanggal = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Tanggal',
                              prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            child: Text(DateFormat('dd MMM yyyy').format(_tanggal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: _waktu);
                            if (picked != null) setState(() => _waktu = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Waktu',
                              prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            child: Text(_waktu.format(context), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Area Utama Dropdown
                  DropdownButtonFormField<String>(
                    value: _masterAreas.contains(_areaCtrl.text) ? _areaCtrl.text : null,
                    decoration: InputDecoration(
                      labelText: 'Area Utama *',
                      prefixIcon: const Icon(Icons.map_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _masterAreas.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _areaCtrl.text = val);
                    },
                    validator: (v) => (_areaCtrl.text.isEmpty) ? 'Area wajib dipilih' : null,
                  ),
                  const SizedBox(height: 14),

                  // Nama Jalan & Segment
                  TextFormField(
                    controller: _namaJalanCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nama Jalan / Jalur Hauling *',
                      prefixIcon: const Icon(Icons.alt_route_rounded, size: 18),
                      hintText: 'Misal: Jalan Manado, Hauling KM 0-33',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama jalan wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _segmentJalanCtrl,
                          decoration: InputDecoration(
                            labelText: 'Segmen / Sta / KM',
                            prefixIcon: const Icon(Icons.pin_drop_rounded, size: 18),
                            hintText: 'Sta 0+000 - 0+100',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _shift,
                          decoration: InputDecoration(
                            labelText: 'Shift',
                            prefixIcon: const Icon(Icons.wb_sunny_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Shift 1 (Siang)', child: Text('Shift 1 (Siang)', style: TextStyle(fontSize: 12.5))),
                            DropdownMenuItem(value: 'Shift 2 (Malam)', child: Text('Shift 2 (Malam)', style: TextStyle(fontSize: 12.5))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _shift = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Lokasi spesifik langsung memakai Koordinat GPS (tanpa field teks duplikat)
                  SapGpsLocationCard(
                    latController: _latCtrl,
                    lngController: _lngCtrl,
                    lokasiController: _lokasiCtrl,
                    primaryColor: _blueColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================= SECTION 1.B: BERITA ACARA TIM SP3 =================
            _sectionHeader('1.B Tim Sidak & Penyetujuan (Standar SP3)', Icons.group_rounded, _blueColor),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _boxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dibuat Oleh (Tim Sidak Bersama)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 18, color: _blueColor),
                          SizedBox(width: 6),
                          Text('Dibuat Oleh (Tim Sidak)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: _blueColor,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: const Text('+ Tambah Rekan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: _addCreator,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._selectedCreators.map((emp) => _memberCard(emp, isApprover: false)),
                  const SizedBox(height: 16),

                  const Divider(),
                  const SizedBox(height: 8),

                  // Disetujui Oleh (Approver) - WAJIB
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_rounded, size: 18, color: _emeraldColor),
                          SizedBox(width: 6),
                          Text('Disetujui Oleh (Approver) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: _emeraldColor,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.shield_outlined, size: 16),
                        label: const Text('+ Tambah Penyetuju', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: _addApprover,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_selectedApprovers.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Penyetuju Belum Dipilih',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF991B1B)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Format SP3 mewajibkan minimal 1 approver.',
                                  style: TextStyle(color: Color(0xFFB91C1C), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _emeraldColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            onPressed: _addApprover,
                            child: const Text('Pilih', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._selectedApprovers.map((emp) => _memberCard(emp, isApprover: true)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================= SECTION 2: 8 PARAMETER BERBASIS 3 PILAR =================
            _sectionHeader('2. Penilaian 8 Parameter (3 Pilar)', Icons.straighten_rounded, _blueColor),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _boxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Global Panjang Segmen
                  Row(
                    children: [
                      const Icon(Icons.straighten_rounded, color: _blueColor, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Panjang Segmen Jalan (Meter)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Standar SP3: 100 Meter per Segmen', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          controller: _panjangSegmentCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          decoration: InputDecoration(
                            suffixText: 'm',
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _blueColor, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // LIVE CONCLUSION CARD (Format Web & Excel SP3)
                  _buildLiveConclusionCard(),
                  const SizedBox(height: 16),

                  // PILAR 1: PERMUKAAN (60%)
                  _pilarBanner('PILAR 1: PERMUKAAN JALAN (BOBOT 60%)', _blueColor),
                  _buildParamCard(
                    title: '1.a Surfacing and Material',
                    weight: 'Bobot 20%',
                    guideline: 'Batu split & tidak terkupas',
                    paramKey: 'Surfacing',
                    deficitCtrl: _defSurfacingCtrl,
                    currentScore: _skorSurfacing,
                  ),
                  _buildParamCard(
                    title: '1.b Undulation / Corrugation',
                    weight: 'Bobot 35%',
                    guideline: 'Bebas lendutan & jalan keriting',
                    paramKey: 'Undulation',
                    deficitCtrl: _defUndulationCtrl,
                    currentScore: _skorUndulation,
                  ),
                  _buildParamCard(
                    title: '1.c Spoil (Lebar Jalan 18m)',
                    weight: 'Bobot 5%',
                    guideline: 'Bebas penyempitan mud spoil/batubara',
                    paramKey: 'Spoil',
                    deficitCtrl: _defSpoilCtrl,
                    currentScore: _skorSpoil,
                  ),
                  const SizedBox(height: 8),

                  // PILAR 2: SAFETY BERM & FASILITAS (20%)
                  _pilarBanner('PILAR 2: SAFETY BERM & FASILITAS (BOBOT 20%)', _emeraldColor),
                  _buildParamCard(
                    title: '2.a Tinggi Tanggul 3/4 Ban',
                    weight: 'Bobot 10%',
                    guideline: 'Standar ≥ 3/4 tinggi ban unit terbesar',
                    paramKey: 'SafetyBerm',
                    deficitCtrl: _defSafetyBermCtrl,
                    currentScore: _skorSafetyBerm,
                  ),
                  _buildParamCard(
                    title: '2.b Road Attachment (Rambu/Delineator)',
                    weight: 'Bobot 5%',
                    guideline: 'Kelengkapan rambu & delineator per 35m',
                    paramKey: 'RoadAttachment',
                    deficitCtrl: _defRoadAttachmentCtrl,
                    currentScore: _skorRoadAttachment,
                  ),
                  _buildParamCard(
                    title: '2.c Dust (Pengendalian Debu)',
                    weight: 'Bobot 5%',
                    guideline: 'Tidak mengganggu jarak pandang',
                    paramKey: 'Dust',
                    deficitCtrl: _defDustCtrl,
                    currentScore: _skorDust,
                  ),
                  const SizedBox(height: 8),

                  // PILAR 3: DRAINAGE & PENIRISAN (20%)
                  _pilarBanner('PILAR 3: DRAINAGE & PENIRISAN (BOBOT 20%)', const Color(0xFF06B6D4)),
                  _buildParamCard(
                    title: '3.a Crossfall Terbentuk (0.5% - 1%)',
                    weight: 'Bobot 10%',
                    guideline: 'Grade melintang 0.5% - 1%',
                    paramKey: 'Crossfall',
                    deficitCtrl: _defCrossfallCtrl,
                    currentScore: _skorCrossfall,
                  ),
                  _buildParamCard(
                    title: '3.b Parit / Tali Air Terbentuk',
                    weight: 'Bobot 10%',
                    guideline: 'Bebas genangan & aliran lancar',
                    paramKey: 'Drainage',
                    deficitCtrl: _defDrainageCtrl,
                    currentScore: _skorDrainage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================= SECTION 3: FOTO & TINDAKAN =================
            _sectionHeader('3. Foto Dokumentasi & Tindakan', Icons.camera_alt_rounded, _blueColor),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _boxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Catatan Observasi Kondisi Jalan
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notes_rounded, size: 16, color: _blueColor),
                            SizedBox(width: 8),
                            Text(
                              'Catatan Observasi Kondisi Jalan',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _catatanCtrl,
                          maxLines: 3,
                          minLines: 2,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Tuliskan temuan atau catatan kondisi aktual di lapangan...',
                            hintStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Rekomendasi Tindakan Perbaikan
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.handyman_rounded, size: 16, color: _blueColor),
                            SizedBox(width: 8),
                            Text(
                              'Rekomendasi Tindakan Perbaikan',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _tindakanCtrl,
                          maxLines: 3,
                          minLines: 2,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Misal: Perlu motor grader meratakan jalan & compactor memadatkan...',
                            hintStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. PIC Tindakan Perbaikan (Data Karyawan Target SAP)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_pin_circle_rounded, size: 16, color: _blueColor),
                          SizedBox(width: 8),
                          Text(
                            'PIC',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _choosePic,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _selectedPicEmployee != null || _picCtrl.text.isNotEmpty
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedPicEmployee != null || _picCtrl.text.isNotEmpty
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_selectedPicEmployee != null)
                                _EmployeeAvatar(
                                  photo: _selectedPicEmployee!.foto,
                                  name: _selectedPicEmployee!.nama,
                                  nik: _selectedPicEmployee!.nik,
                                  radius: 22,
                                  fallbackBg: const Color(0xFFDCFCE7),
                                  fallbackFg: const Color(0xFF16A34A),
                                )
                              else if (_picCtrl.text.isNotEmpty)
                                _EmployeeAvatar(
                                  photo: null,
                                  name: _picCtrl.text,
                                  nik: '',
                                  radius: 22,
                                  fallbackBg: const Color(0xFFDCFCE7),
                                  fallbackFg: const Color(0xFF16A34A),
                                )
                              else
                                const CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Color(0xFFE0F2FE),
                                  child: Icon(
                                    Icons.person_search_rounded,
                                    color: Color(0xFF0284C7),
                                    size: 24,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedPicEmployee?.nama ?? (_picCtrl.text.isNotEmpty ? _picCtrl.text : 'Pilih PIC'),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: _selectedPicEmployee != null || _picCtrl.text.isNotEmpty
                                            ? const Color(0xFF14532D)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedPicEmployee != null
                                          ? '${_selectedPicEmployee!.nik} • ${_selectedPicEmployee!.jabatan} (${_selectedPicEmployee!.perusahaan})'
                                          : (_picCtrl.text.isNotEmpty
                                              ? 'PIC Terpilih'
                                              : 'Ketuk untuk memilih PIC...'),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: _selectedPicEmployee != null || _picCtrl.text.isNotEmpty
                                            ? const Color(0xFF166534)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedPicEmployee != null || _picCtrl.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                                  onPressed: () {
                                    setState(() {
                                      _selectedPicEmployee = null;
                                      _picCtrl.clear();
                                    });
                                  },
                                )
                              else
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 4. Foto Dokumentasi Kondisi Jalan (Ultra-Premium Card)
                  const Row(
                    children: [
                      Icon(Icons.photo_camera_back_rounded, size: 16, color: _blueColor),
                      SizedBox(width: 8),
                      Text(
                        'Foto Dokumentasi Kondisi Jalan',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_fotoFile != null || (_existingFotoUrl != null && _existingFotoUrl!.isNotEmpty))
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            if (_fotoFile != null)
                              Image.file(_fotoFile!, width: double.infinity, height: 210, fit: BoxFit.cover)
                            else
                              Image.network(
                                _existingFotoUrl!.startsWith('http')
                                    ? _existingFotoUrl!
                                    : '${ApiService().baseUrl}$_existingFotoUrl',
                                width: double.infinity,
                                height: 210,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 210,
                                  color: const Color(0xFFF1F5F9),
                                  alignment: Alignment.center,
                                  child: const Text('Foto tidak dapat dimuat', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                ),
                              ),
                            // Top Overlay Bar
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.black54, Colors.transparent],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                                          SizedBox(width: 4),
                                          Text('Foto Dokumentasi Jalan', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      radius: 15,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                        onPressed: () => setState(() {
                                          _fotoFile = null;
                                          _existingFotoUrl = null;
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Bottom Action Banner
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                color: Colors.black54,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Foto siap dilampirkan',
                                      style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                                    ),
                                    InkWell(
                                      onTap: () => _pickImage(ImageSource.camera),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.cached_rounded, color: Color(0xFF93C5FD), size: 14),
                                          SizedBox(width: 4),
                                          Text('Ganti Foto', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _blueColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_a_photo_rounded, color: _blueColor, size: 24),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Unggah Bukti Foto Kondisi Jalan',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Lampirkan foto kondisi aktual permukaan jalan, tanggul berm, atau drainase (JPG/PNG)',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                  label: const Text('Kamera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _blueColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickImage(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library_rounded, size: 16, color: _blueColor),
                                  label: const Text('Galeri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _blueColor)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: _blueColor, width: 1.2),
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==================== Sub-Widgets ====================

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildEmployeeAvatar(
    String? photo,
    String name,
    String nik, {
    double radius = 18,
    Color? fallbackBg,
    Color? fallbackFg,
  }) {
    return _EmployeeAvatar(
      photo: photo,
      name: name,
      nik: nik,
      radius: radius,
      fallbackBg: fallbackBg,
      fallbackFg: fallbackFg,
    );
  }

  Widget _memberCard(_EmployeeOption emp, {required bool isApprover}) {
    final color = isApprover ? _emeraldColor : _blueColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildEmployeeAvatar(
            emp.foto,
            emp.nama,
            emp.nik,
            radius: 19,
            fallbackBg: color.withValues(alpha: 0.12),
            fallbackFg: color,
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
                        emp.nama,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (emp.isPrimary) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _blueColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Anda', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${emp.nik} • ${emp.jabatan}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  emp.perusahaan,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!emp.isPrimary)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: Colors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  if (isApprover) {
                    _selectedApprovers.removeWhere((x) => x.nik == emp.nik);
                  } else {
                    _selectedCreators.removeWhere((x) => x.nik == emp.nik);
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _pilarBanner(String title, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: color),
      ),
    );
  }

  Widget _buildParamCard({
    required String title,
    required String weight,
    required String guideline,
    required String paramKey,
    required TextEditingController deficitCtrl,
    required double currentScore,
  }) {
    final totalLen = _panjangSegmenVal > 0 ? _panjangSegmenVal : 100.0;
    final def = double.tryParse(deficitCtrl.text) ?? 0.0;
    final pct = ((totalLen - def) / totalLen * 100.0).clamp(0.0, 100.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    const SizedBox(height: 1),
                    Text(guideline, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _blueColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(weight, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _blueColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Deficit Input
          Row(
            children: [
              const Text('Defisit (meter):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: deficitCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    suffixText: 'm',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _blueColor, width: 1.5),
                    ),
                  ),
                  onChanged: (val) => _onDeficitChanged(paramKey, val),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: currentScore >= 3.5 ? _emeraldColor.withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${pct.toStringAsFixed(1)}% (Skor: ${currentScore.toStringAsFixed(1)})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: currentScore >= 3.5 ? _emeraldColor : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 5 Score Buttons: 4.0, 3.5, 3.0, 2.5, 2.0
          Row(
            children: [
              _scoreButton(paramKey, 4.0, '0% Def', currentScore == 4.0),
              const SizedBox(width: 4),
              _scoreButton(paramKey, 3.5, '≤10%', currentScore == 3.5),
              const SizedBox(width: 4),
              _scoreButton(paramKey, 3.0, '11-20%', currentScore == 3.0),
              const SizedBox(width: 4),
              _scoreButton(paramKey, 2.5, '21-50%', currentScore == 2.5),
              const SizedBox(width: 4),
              _scoreButton(paramKey, 2.0, '>50%', currentScore == 2.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreButton(String paramKey, double score, String label, bool active) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            HapticFeedback.lightImpact();
            _onManualScoreTapped(paramKey, score);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: active ? _blueColor : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? _blueColor : Colors.grey.shade300,
                width: active ? 1.5 : 1.0,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _blueColor.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: active ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? Colors.white.withValues(alpha: 0.9) : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveConclusionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _scoreColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _scoreColor.withValues(alpha: 0.08),
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EVALUASI SEGMEN JALAN (RCI)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Target Operasional 4.00 (Draft SP3)', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _scoreColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_actualRoadScore.toStringAsFixed(2)} / 4.00 (${_achievement.toStringAsFixed(1)}%)',
                  style: TextStyle(color: _scoreColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3-Group Table
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _grpPilarItem('Permukaan (60%)', _skorPermukaanGroup, _blueColor),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                _grpPilarItem('Berm (20%)', _skorSafetyBermGroup, _emeraldColor),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                _grpPilarItem('Drainase (20%)', _skorDrainageGroup, const Color(0xFF06B6D4)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Auto Recommendation preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF16A34A)),
                        SizedBox(width: 4),
                        Text('Rekomendasi Otomatis:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF166534))),
                      ],
                    ),
                    InkWell(
                      onTap: _applyAutoRecommendation,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Text('Salin ke Form', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _generateAutoRecommendation(),
                  style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grpPilarItem(String title, double score, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(score.toStringAsFixed(2), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ==================== Dedicated Target SAP Employee Picker Sheet ====================
class _RciEmployeePickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color themeColor;

  const _RciEmployeePickerSheet({
    required this.title,
    required this.subtitle,
    this.themeColor = const Color(0xFF1D4ED8),
  });

  @override
  State<_RciEmployeePickerSheet> createState() => _RciEmployeePickerSheetState();
}

class _RciEmployeePickerSheetState extends State<_RciEmployeePickerSheet> {
  final _searchCtrl = TextEditingController();
  final _api = ApiService();
  final _db = DatabaseService();
  List<_EmployeeOption> _allLoadedResults = [];
  List<_EmployeeOption> _displayedResults = [];
  bool _isLoading = true;
  bool _isOffline = false;
  bool _filterOnlyMyCompany = false;
  Timer? _debounce;

  late String _userCompany;
  late int _userCompanyId;

  @override
  void initState() {
    super.initState();
    final profile = PreferenceService.getProfile();
    _userCompany = (profile?.company ?? '').trim();
    _userCompanyId = profile?.companyId ?? 0;
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool _isMyCompany(_EmployeeOption emp) {
    if (_userCompanyId > 0 && emp.perusahaanId != null && emp.perusahaanId == _userCompanyId) {
      return true;
    }
    if (_userCompany.isNotEmpty) {
      final cleanUser = _userCompany.toLowerCase();
      final cleanEmp = emp.perusahaan.toLowerCase();
      return cleanEmp == cleanUser || cleanEmp.contains(cleanUser) || cleanUser.contains(cleanEmp);
    }
    return false;
  }

  void _applyFilter() {
    if (!_filterOnlyMyCompany) {
      _displayedResults = List.from(_allLoadedResults);
    } else {
      _displayedResults = _allLoadedResults.where((e) => _isMyCompany(e)).toList();
    }
  }

  Future<void> _loadInitialData() async {
    // 1. Instantly show local SQLite cache with login company prioritized
    try {
      final db = await _db.database;
      final safeCompany = _userCompany.replaceAll("'", "''");
      final rows = await db.rawQuery('''
        SELECT no_nik, nama_lengkap, depart, posisi, departemen, jabatan, perusahaan, foto, company_id 
        FROM employees 
        WHERE no_nik IS NOT NULL AND nama_lengkap IS NOT NULL AND nama_lengkap != ''
        ORDER BY 
          CASE 
            WHEN ($_userCompanyId > 0 AND company_id = $_userCompanyId) OR (perusahaan IS NOT NULL AND perusahaan = '$safeCompany') THEN 0 
            WHEN ('$safeCompany' != '' AND perusahaan LIKE '%$safeCompany%') THEN 1 
            ELSE 2 
          END,
          nama_lengkap ASC
        LIMIT 80
      ''');

      if (rows.isNotEmpty && mounted && _allLoadedResults.isEmpty) {
        setState(() {
          _allLoadedResults = rows.map((r) {
            final rawComp = r['company_id'];
            final int? compId = rawComp is int ? rawComp : int.tryParse(rawComp?.toString() ?? '');
            return _EmployeeOption(
              nik: r['no_nik']?.toString().trim() ?? '',
              nama: r['nama_lengkap']?.toString().trim() ?? '',
              jabatan: (r['jabatan'] ?? r['posisi'])?.toString().trim() ?? 'Staff',
              departemen: (r['departemen'] ?? r['depart'])?.toString().trim() ?? '',
              perusahaan: r['perusahaan']?.toString().trim() ?? '',
              perusahaanId: compId,
              foto: r['foto']?.toString().trim(),
            );
          }).toList();
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. Fetch fresh Target SAP employee list from server
    _loadEmployees('');
  }

  Future<void> _loadEmployees(String q) async {
    final cleanQ = q.trim();
    bool serverOk = false;
    try {
      final list = await _api.searchRciEmployees(
        cleanQ,
        companyId: _userCompanyId > 0 ? _userCompanyId : null,
        companyName: _userCompany.isNotEmpty ? _userCompany : null,
        limit: 80,
      );

      if (list.isNotEmpty && mounted) {
        serverOk = true;
        final mapped = list.map((e) => _EmployeeOption(
          nik: e['nik']?.toString() ?? '',
          nama: e['nama']?.toString() ?? '',
          jabatan: e['jabatan']?.toString() ?? 'Staff',
          departemen: e['departemen']?.toString() ?? '',
          perusahaan: e['perusahaan']?.toString() ?? '',
          perusahaanId: e['perusahaanId'] is int ? e['perusahaanId'] : int.tryParse(e['perusahaanId']?.toString() ?? ''),
          foto: e['foto']?.toString(),
        )).toList();

        setState(() {
          _allLoadedResults = mapped;
          _applyFilter();
          _isLoading = false;
          _isOffline = false;
        });

        // Background cache upsert to local SQLite employees table
        _cacheEmployeesToDb(list);
        return;
      }
    } catch (_) {
      serverOk = false;
    }

    // 3. Fallback to SQLite (Offline Mode or server down/empty)
    try {
      final db = await _db.database;
      final safeCompany = _userCompany.replaceAll("'", "''");
      final safeQ = cleanQ.replaceAll("'", "''");

      final String query;
      if (cleanQ.isEmpty) {
        query = '''
          SELECT no_nik, nama_lengkap, depart, posisi, departemen, jabatan, perusahaan, foto, company_id 
          FROM employees 
          WHERE no_nik IS NOT NULL AND nama_lengkap IS NOT NULL AND nama_lengkap != ''
          ORDER BY 
            CASE 
              WHEN ($_userCompanyId > 0 AND company_id = $_userCompanyId) OR (perusahaan IS NOT NULL AND perusahaan = '$safeCompany') THEN 0 
              WHEN ('$safeCompany' != '' AND perusahaan LIKE '%$safeCompany%') THEN 1 
              ELSE 2 
            END,
            nama_lengkap ASC
          LIMIT 80
        ''';
      } else {
        query = '''
          SELECT no_nik, nama_lengkap, depart, posisi, departemen, jabatan, perusahaan, foto, company_id 
          FROM employees 
          WHERE (no_nik LIKE '%$safeQ%' OR nama_lengkap LIKE '%$safeQ%' OR depart LIKE '%$safeQ%' OR departemen LIKE '%$safeQ%' OR jabatan LIKE '%$safeQ%' OR posisi LIKE '%$safeQ%' OR perusahaan LIKE '%$safeQ%')
            AND nama_lengkap IS NOT NULL AND nama_lengkap != ''
          ORDER BY 
            CASE 
              WHEN ($_userCompanyId > 0 AND company_id = $_userCompanyId) OR (perusahaan IS NOT NULL AND perusahaan = '$safeCompany') THEN 0 
              WHEN ('$safeCompany' != '' AND perusahaan LIKE '%$safeCompany%') THEN 1 
              ELSE 2 
            END,
            nama_lengkap ASC
          LIMIT 60
        ''';
      }

      final rows = await db.rawQuery(query);
      if (mounted) {
        setState(() {
          _allLoadedResults = rows.map((r) {
            final rawComp = r['company_id'];
            final int? compId = rawComp is int ? rawComp : int.tryParse(rawComp?.toString() ?? '');
            return _EmployeeOption(
              nik: r['no_nik']?.toString().trim() ?? '',
              nama: r['nama_lengkap']?.toString().trim() ?? '',
              jabatan: (r['jabatan'] ?? r['posisi'])?.toString().trim() ?? 'Staff',
              departemen: (r['departemen'] ?? r['depart'])?.toString().trim() ?? '',
              perusahaan: r['perusahaan']?.toString().trim() ?? '',
              perusahaanId: compId,
              foto: r['foto']?.toString().trim(),
            );
          }).toList();
          _applyFilter();
          _isLoading = false;
          _isOffline = !serverOk;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cacheEmployeesToDb(List<Map<String, dynamic>> items) async {
    try {
      final db = await _db.database;
      final batch = db.batch();
      for (final e in items) {
        final nik = e['nik']?.toString().trim() ?? '';
        final nama = e['nama']?.toString().trim() ?? '';
        if (nik.isEmpty || nama.isEmpty) continue;
        batch.rawInsert('''
          INSERT OR REPLACE INTO employees 
          (no_nik, nama_lengkap, departemen, depart, jabatan, posisi, perusahaan, company_id, foto)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          nik,
          nama,
          e['departemen'] ?? '',
          e['departemen'] ?? '',
          e['jabatan'] ?? 'Staff',
          e['jabatan'] ?? 'Staff',
          e['perusahaan'] ?? '',
          e['perusahaanId'] ?? 0,
          e['foto'] ?? '',
        ]);
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _loadEmployees(val);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            // Tab Filter: Semua vs Perusahaan Saya
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Semua Karyawan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    selected: !_filterOnlyMyCompany,
                    selectedColor: widget.themeColor.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: !_filterOnlyMyCompany ? widget.themeColor : const Color(0xFF64748B),
                    ),
                    side: BorderSide(
                      color: !_filterOnlyMyCompany ? widget.themeColor : const Color(0xFFE2E8F0),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _filterOnlyMyCompany = false;
                          _applyFilter();
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ChoiceChip(
                      avatar: const Icon(Icons.business_rounded, size: 14),
                      label: Text(
                        _userCompany.isNotEmpty ? _userCompany : 'Perusahaan Saya',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: _filterOnlyMyCompany,
                      selectedColor: const Color(0xFF0D5C75).withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: _filterOnlyMyCompany ? const Color(0xFF0D5C75) : const Color(0xFF64748B),
                      ),
                      side: BorderSide(
                        color: _filterOnlyMyCompany ? const Color(0xFF0D5C75) : const Color(0xFFE2E8F0),
                      ),
                      onSelected: (val) {
                        setState(() {
                          _filterOnlyMyCompany = val;
                          _applyFilter();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Cari nama, NIK, atau perusahaan...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _loadEmployees('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            // Offline mode notice banner
            if (_isOffline)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 14, color: Color(0xFFB45309)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Mode Offline: Menampilkan data pengawas tersimpan di perangkat',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),
            Expanded(
              child: _isLoading && _displayedResults.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _displayedResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                _filterOnlyMyCompany
                                    ? 'Tidak ada karyawan di perusahaan $_userCompany'
                                    : 'Karyawan tidak ditemukan',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          itemCount: _displayedResults.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (ctx, i) {
                            final emp = _displayedResults[i];
                            final isMyComp = _isMyCompany(emp);

                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(context, emp);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    _EmployeeAvatar(
                                      photo: emp.foto,
                                      name: emp.nama,
                                      nik: emp.nik,
                                      radius: 22,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  emp.nama,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13.5,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isMyComp) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDCFCE7),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                                  ),
                                                  child: const Text(
                                                    'Perusahaan Anda',
                                                    style: TextStyle(
                                                      color: Color(0xFF166534),
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'NIK: ${emp.nik}${emp.departemen.isNotEmpty ? ' • ${emp.departemen}' : ''} • ${emp.jabatan}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isMyComp ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              emp.perusahaan.isNotEmpty ? emp.perusahaan : 'Mitra',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: isMyComp ? const Color(0xFF15803D) : const Color(0xFF475569),
                                                fontWeight: isMyComp ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

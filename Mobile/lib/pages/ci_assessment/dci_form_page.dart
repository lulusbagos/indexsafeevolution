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
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';
import 'dci_model.dart';

class _DciEmployeeItem {
  final String nik;
  final String nama;
  final String departemen;
  final String jabatan;
  final String perusahaan;
  final int? perusahaanId;
  final String? foto;

  _DciEmployeeItem({
    required this.nik,
    required this.nama,
    required this.departemen,
    required this.jabatan,
    required this.perusahaan,
    this.perusahaanId,
    this.foto,
  });

  String get displayName => '$nama ($nik) • $jabatan';
}

class _DciEmployeeAvatar extends StatefulWidget {
  final String? photo;
  final String name;
  final String nik;
  final double radius;
  final Color? fallbackBg;
  final Color? fallbackFg;

  const _DciEmployeeAvatar({
    required this.photo,
    required this.name,
    required this.nik,
    this.radius = 18,
    this.fallbackBg,
    this.fallbackFg,
  });

  @override
  State<_DciEmployeeAvatar> createState() => _DciEmployeeAvatarState();
}

class _DciEmployeeAvatarState extends State<_DciEmployeeAvatar> {
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
  void didUpdateWidget(covariant _DciEmployeeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo || oldWidget.nik != widget.nik) {
      _attempt = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.trim().isNotEmpty ? widget.name.trim()[0].toUpperCase() : 'U';
    final bg = widget.fallbackBg ?? const Color(0xFFFFF7ED);
    final fg = widget.fallbackFg ?? const Color(0xFFEA580C);

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
      child: Image.network(
        url,
        width: widget.radius * 2,
        height: widget.radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
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
      ),
    );
  }
}

class DciFormPage extends StatefulWidget {
  final DciReportItem? editData;

  const DciFormPage({super.key, this.editData});

  @override
  State<DciFormPage> createState() => _DciFormPageState();
}

class _DciFormPageState extends State<DciFormPage> {
  final _api = ApiService();
  final _db = DatabaseService();
  final _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();

  // Perusahaan & Mitra
  int? _selectedCompanyId;
  String? _selectedCompanyName;

  // Lokasi & Waktu
  late DateTime _tanggal;
  late TimeOfDay _waktu;
  final _areaCtrl = TextEditingController();
  final _lokasiCtrl = TextEditingController();
  final _detilLokasiCtrl = TextEditingController();
  final _disposalCtrl = TextEditingController();
  final _namaDumpCtrl = TextEditingController();
  final _padCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  String _shift = 'Shift 1 (Siang)';

  // 8 Parameters (100, 70, 40, 0)
  int _skorLantaiDump = 100;
  int _skorSafetyBerm = 100;
  int _skorKondisiCrest = 100;
  int _skorGradeDumping = 100;
  int _skorDrainaseDump = 100;
  int _skorPenataanSpillage = 100;
  int _skorRambuPenerangan = 100;
  int _skorSpotterManuver = 100;

  // Catatan, Tindakan, Foto
  final _catatanCtrl = TextEditingController();
  final _tindakanCtrl = TextEditingController();
  final _picCtrl = TextEditingController();
  _DciEmployeeItem? _selectedPicEmployee;
  File? _fotoFile;
  String? _existingFotoUrl;

  bool _isSaving = false;

  // Master Area & Disposal
  List<String> _masterAreas = [];
  List<String> _masterDisposals = [];
  bool _isLoadingAreas = false;
  bool _isLoadingDisposals = false;

  static const _orangeColor = Color(0xFFEA580C);
  static const _orangeAccent = Color(0xFFFB923C);
  static const _orangeGradient = LinearGradient(
    colors: [Color(0xFFEA580C), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _tanggal = DateTime(now.year, now.month, now.day);
    _waktu = TimeOfDay.now();

    final profile = PreferenceService.getProfile();
    _selectedCompanyId = profile?.companyId;
    _selectedCompanyName = profile?.company;

    if (widget.editData != null) {
      final d = widget.editData!;
      if (d.perusahaanId != null && d.perusahaanId! > 0) {
        _selectedCompanyId = d.perusahaanId;
      }
      if (d.perusahaan != null && d.perusahaan!.isNotEmpty) {
        _selectedCompanyName = d.perusahaan;
      }

      _tanggal = d.tanggal;
      final parts = d.waktu.split(':');
      if (parts.length >= 2) {
        _waktu = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? now.hour,
          minute: int.tryParse(parts[1]) ?? now.minute,
        );
      }
      _areaCtrl.text = d.area;
      _lokasiCtrl.text = d.lokasi;
      _detilLokasiCtrl.text = d.detilLokasi ?? '';
      _disposalCtrl.text = d.disposal ?? '';
      _namaDumpCtrl.text = d.namaDump ?? '';
      _padCtrl.text = d.pad ?? '';
      _latCtrl.text = d.latitude ?? '';
      _lngCtrl.text = d.longitude ?? '';
      _shift = d.shift ?? 'Shift 1 (Siang)';

      _skorLantaiDump = d.skorLantaiDump;
      _skorSafetyBerm = d.skorSafetyBerm;
      _skorKondisiCrest = d.skorKondisiCrest;
      _skorGradeDumping = d.skorGradeDumping;
      _skorDrainaseDump = d.skorDrainaseDump;
      _skorPenataanSpillage = d.skorPenataanSpillage;
      _skorRambuPenerangan = d.skorRambuPenerangan;
      _skorSpotterManuver = d.skorSpotterManuver;

      _catatanCtrl.text = d.catatan ?? '';
      _tindakanCtrl.text = d.tindakanPerbaikan ?? '';
      _picCtrl.text = d.pic ?? '';
      _existingFotoUrl = d.fotoUrl;
    }

    _loadAreas();
    _loadDisposals();
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _lokasiCtrl.dispose();
    _detilLokasiCtrl.dispose();
    _disposalCtrl.dispose();
    _namaDumpCtrl.dispose();
    _padCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _catatanCtrl.dispose();
    _tindakanCtrl.dispose();
    _picCtrl.dispose();
    super.dispose();
  }

  // Live Score Calculation
  double get _totalScore {
    final s = (_skorLantaiDump * 0.15) +
        (_skorSafetyBerm * 0.15) +
        (_skorKondisiCrest * 0.15) +
        (_skorGradeDumping * 0.15) +
        (_skorDrainaseDump * 0.10) +
        (_skorPenataanSpillage * 0.10) +
        (_skorRambuPenerangan * 0.10) +
        (_skorSpotterManuver * 0.10);
    return double.parse(s.toStringAsFixed(1));
  }

  String get _kategoriIndex {
    if (_totalScore >= 85) return 'Baik';
    if (_totalScore >= 70) return 'Sedang';
    return 'Kurang';
  }

  Color get _categoryColor {
    if (_totalScore >= 85) return const Color(0xFF10B981);
    if (_totalScore >= 70) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  // Load Areas
  Future<void> _loadAreas() async {
    setState(() => _isLoadingAreas = true);
    try {
      final profile = PreferenceService.getProfile();
      final companyId = profile?.companyId;

      final sqldb = await _db.database;
      final localAreas = await sqldb.rawQuery(
        "SELECT DISTINCT area_utama FROM tbl_m_benchmark WHERE area_utama IS NOT NULL AND area_utama != '' ORDER BY area_utama",
      );

      if (localAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = localAreas.map((e) => e['area_utama'].toString().trim()).toList();
        });
      }

      final serverAreas = await _api.getMasterAreas(perusahaanId: companyId);
      if (serverAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = serverAreas;
          _isLoadingAreas = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAreas = false);
    }
  }

  // Load Disposals
  Future<void> _loadDisposals() async {
    setState(() => _isLoadingDisposals = true);
    final Set<String> disposals = {};
    try {
      final sqldb = await _db.database;
      final rows = await sqldb.rawQuery(
        "SELECT DISTINCT disposal FROM tbl_t_dci_report WHERE disposal IS NOT NULL AND disposal != '' ORDER BY disposal",
      );
      for (final r in rows) {
        final val = r['disposal']?.toString().trim();
        if (val != null && val.isNotEmpty) disposals.add(val);
      }
    } catch (_) {}

    try {
      final res = await _api.getDciSuggestions();
      res.fold((_) {}, (data) {
        final list = (data['disposals'] as List<dynamic>? ?? []).map((e) => e.toString().trim());
        disposals.addAll(list.where((e) => e.isNotEmpty));
      });
    } catch (_) {}

    disposals.addAll([
      'Disposal Utara',
      'Disposal Selatan',
      'Disposal Timur',
      'Disposal Barat',
      'In-Pit Dump Pit 1',
      'In-Pit Dump Pit 2',
      'Out-Pit Dump Alpha',
      'Out-Pit Dump Bravo',
      'Waste Dump Crest 120',
      'Low Grade Stockpile Dump',
    ]);

    if (mounted) {
      setState(() {
        _masterDisposals = disposals.toList()..sort();
        _isLoadingDisposals = false;
      });
    }
  }

  // Pick Image
  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() {
          _fotoFile = File(file.path);
        });
      }
    } catch (e) {
      _showSnack('Gagal mengambil gambar: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ==================== Target SAP Employee Picker Modal ====================
  Future<_DciEmployeeItem?> _openEmployeePicker({
    required String title,
    required String subtitle,
    required Color themeColor,
  }) {
    return showModalBottomSheet<_DciEmployeeItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DciEmployeePickerSheet(
        title: title,
        subtitle: subtitle,
        themeColor: themeColor,
      ),
    );
  }

  void _choosePic() async {
    final emp = await _openEmployeePicker(
      title: 'Pilih PIC',
      subtitle: 'Pilih penanggung jawab disposal',
      themeColor: _orangeColor,
    );
    if (emp != null && mounted) {
      setState(() {
        _selectedPicEmployee = emp;
        _picCtrl.text = '${emp.nama} (${emp.nik})';
      });
    }
  }

  // Disposal Picker Modal
  void _showDisposalPicker() {
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = _masterDisposals
                .where((d) => d.toLowerCase().contains(search.toLowerCase().trim()))
                .toList();
            final canAddCustom = search.trim().isNotEmpty && !filtered.any((d) => d.toLowerCase() == search.toLowerCase().trim());

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.terrain_rounded, color: _orangeColor, size: 26),
                        SizedBox(width: 10),
                        Text('Pilih Area Disposal / Dump',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        onChanged: (val) => setModalState(() => search = val),
                        decoration: const InputDecoration(
                          hintText: 'Cari atau ketik nama disposal...',
                          prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (canAddCustom)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(modalCtx);
                          setState(() {
                            _disposalCtrl.text = search.trim();
                            if (_namaDumpCtrl.text.isEmpty) {
                              _namaDumpCtrl.text = search.trim();
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _orangeAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle, color: _orangeColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('Gunakan "${search.trim()}"',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: _orangeColor)),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: _orangeColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (_, idx) {
                        final item = filtered[idx];
                        final isSelected = item == _disposalCtrl.text;
                        return ListTile(
                          title: Text(item,
                              style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? _orangeColor : const Color(0xFF1E293B))),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: _orangeColor) : null,
                          onTap: () {
                            Navigator.pop(modalCtx);
                            setState(() {
                              _disposalCtrl.text = item;
                              if (_namaDumpCtrl.text.isEmpty) {
                                _namaDumpCtrl.text = item;
                              }
                            });
                          },
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

  // Area Picker Modal
  void _showAreaPicker() {
    String filter = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = _masterAreas
                .where((a) => a.toLowerCase().contains(filter.toLowerCase().trim()))
                .toList();

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.map_rounded, color: _orangeColor, size: 26),
                        SizedBox(width: 10),
                        Text('Pilih Area Operasional',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        onChanged: (val) => setModalState(() => filter = val),
                        decoration: const InputDecoration(
                          hintText: 'Cari nama area...',
                          prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (_, idx) {
                        final item = filtered[idx];
                        final isSelected = item == _areaCtrl.text;
                        return ListTile(
                          title: Text(item,
                              style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? _orangeColor : const Color(0xFF1E293B))),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: _orangeColor) : null,
                          onTap: () {
                            Navigator.pop(modalCtx);
                            setState(() {
                              _areaCtrl.text = item;
                              if (_lokasiCtrl.text.isEmpty) {
                                _lokasiCtrl.text = item;
                              }
                            });
                          },
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

  // Save Report
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack('Mohon lengkapi semua field bertanda bintang (*)');
      return;
    }

    if (_disposalCtrl.text.trim().isEmpty) {
      _showSnack('Area Disposal wajib diisi!');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = PreferenceService.getProfile();
      final userNik = profile?.noNik ?? PreferenceService.getUser() ?? '';
      final userName = profile?.namaLengkap ?? '';
      final userDept = profile?.depart ?? '';
      final userComp = profile?.company ?? '';
      final userCompId = profile?.companyId ?? 0;

      final waktuFormatted = '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}';
      final tanggalFormatted = DateFormat('yyyy-MM-dd').format(_tanggal);

      final map = <String, dynamic>{
        'tanggal': tanggalFormatted,
        'waktu': waktuFormatted,
        'nik': userNik,
        'nama': userName,
        'departemen': userDept,
        'perusahaan': _selectedCompanyName ?? userComp,
        'perusahaan_id': _selectedCompanyId ?? userCompId,
        'area': _areaCtrl.text.trim().isNotEmpty ? _areaCtrl.text.trim() : 'Area Tambang',
        'lokasi': _lokasiCtrl.text.trim().isNotEmpty ? _lokasiCtrl.text.trim() : _areaCtrl.text.trim(),
        'detil_lokasi': _detilLokasiCtrl.text.trim(),
        'disposal': _disposalCtrl.text.trim(),
        'nama_dump': _namaDumpCtrl.text.trim().isNotEmpty ? _namaDumpCtrl.text.trim() : _disposalCtrl.text.trim(),
        'pad': _padCtrl.text.trim(),
        'shift': _shift,
        'latitude': _latCtrl.text.trim(),
        'longitude': _lngCtrl.text.trim(),
        'skor_lantai_dump': _skorLantaiDump,
        'skor_safety_berm': _skorSafetyBerm,
        'skor_kondisi_crest': _skorKondisiCrest,
        'skor_grade_dumping': _skorGradeDumping,
        'skor_drainase_dump': _skorDrainaseDump,
        'skor_penataan_spillage': _skorPenataanSpillage,
        'skor_rambu_penerangan': _skorRambuPenerangan,
        'skor_spotter_manuver': _skorSpotterManuver,
        'total_score': _totalScore,
        'kategori_index': _kategoriIndex,
        'catatan': _catatanCtrl.text.trim(),
        'tindakan_perbaikan': _tindakanCtrl.text.trim(),
        'pic': _picCtrl.text.trim(),
      };

      if (widget.editData != null) {
        map['id'] = widget.editData!.id;
      }

      final formData = FormData.fromMap(map);

      if (_fotoFile != null && await _fotoFile!.exists()) {
        final fileName = _fotoFile!.path.split(Platform.pathSeparator).last;
        formData.files.add(
          MapEntry(
            'foto',
            await MultipartFile.fromFile(_fotoFile!.path, filename: fileName),
          ),
        );
      }

      bool isSavedOnline = false;
      try {
        final res = await _api.saveDciReport(formData);
        res.fold(
          (err) {
            isSavedOnline = false;
          },
          (data) {
            isSavedOnline = true;
          },
        );
      } catch (_) {
        isSavedOnline = false;
      }

      // Offline sync queue fallback
      if (!isSavedOnline && widget.editData == null) {
        final cleanMap = Map<String, dynamic>.from(map);
        final localId = 'dci_${DateTime.now().millisecondsSinceEpoch}';
        await OfflineSyncService.instance.enqueue(
          feature: 'dci',
          localId: localId,
          payload: {
            'map': cleanMap,
            if (_fotoFile != null) 'photoPath': _fotoFile!.path,
          },
        );
      }

      // Save locally to SQLite so offline mode and cache stay in sync
      try {
        final sqldb = await _db.database;
        final localData = <String, dynamic>{
          'tanggal': tanggalFormatted,
          'waktu': waktuFormatted,
          'nik': userNik,
          'nama': userName,
          'departemen': userDept,
          'perusahaan': _selectedCompanyName ?? userComp,
          'perusahaan_id': _selectedCompanyId ?? userCompId,
          'area': _areaCtrl.text.trim().isNotEmpty ? _areaCtrl.text.trim() : 'Area Tambang',
          'lokasi': _lokasiCtrl.text.trim().isNotEmpty ? _lokasiCtrl.text.trim() : _areaCtrl.text.trim(),
          'detil_lokasi': _detilLokasiCtrl.text.trim(),
          'disposal': _disposalCtrl.text.trim(),
          'nama_dump': _namaDumpCtrl.text.trim(),
          'pad': _padCtrl.text.trim(),
          'shift': _shift,
          'latitude': _latCtrl.text.trim(),
          'longitude': _lngCtrl.text.trim(),
          'skor_lantai_dump': _skorLantaiDump,
          'skor_safety_berm': _skorSafetyBerm,
          'skor_kondisi_crest': _skorKondisiCrest,
          'skor_grade_dumping': _skorGradeDumping,
          'skor_drainase_dump': _skorDrainaseDump,
          'skor_penataan_spillage': _skorPenataanSpillage,
          'skor_rambu_penerangan': _skorRambuPenerangan,
          'skor_spotter_manuver': _skorSpotterManuver,
          'total_score': _totalScore,
          'kategori_index': _kategoriIndex,
          'catatan': _catatanCtrl.text.trim(),
          'tindakan_perbaikan': _tindakanCtrl.text.trim(),
          'pic': _picCtrl.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        };
        if (_fotoFile != null) {
          localData['foto_url'] = _fotoFile!.path;
        } else if (_existingFotoUrl != null) {
          localData['foto_url'] = _existingFotoUrl;
        }

        if (widget.editData != null) {
          await sqldb.update('tbl_t_dci_report', localData, where: 'id = ?', whereArgs: [widget.editData!.id]);
        } else {
          await sqldb.insert('tbl_t_dci_report', localData);
        }
      } catch (_) {}

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
                  isSavedOnline ? Icons.check_circle : Icons.cloud_off_rounded,
                  color: isSavedOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(isSavedOnline ? 'Berhasil Disimpan!' : 'Disimpan Offline'),
              ],
            ),
            content: Text(
              isSavedOnline
                  ? (widget.editData != null
                      ? 'Laporan DCI berhasil diperbarui di server.'
                      : 'Laporan DCI baru berhasil dikirim dan tersimpan di server.')
                  : 'Laporan DCI tersimpan di perangkat (Mode Offline) dan akan disinkronkan otomatis saat ada koneksi.',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orangeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('OK'),
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = widget.editData != null && widget.editData!.tanggal.isBefore(today)
        ? widget.editData!.tanggal
        : today;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: TopBar(title: widget.editData != null ? 'Edit Inspeksi DCI' : 'Form Inspeksi DCI'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: _orangeGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x33EA580C), blurRadius: 14, offset: Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.terrain_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Disposal Condition Index (DCI)',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Standar Evaluasi K3 Teknis Dumping Area',
                            style: TextStyle(color: Color(0xFFFED7AA), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live Score Indicator Card
            _buildLiveScoreCard(),
            const SizedBox(height: 16),

            // Section 1: Lokasi & Waktu
            _buildSectionCard(
              title: '1. Identifikasi Area & Disposal',
              icon: Icons.location_on_rounded,
              children: [
                // Perusahaan & Mitra Kerja (Default sama dengan login, tapi user bisa ubah/ganti)
                CompanyDropdown(
                  initialCompanyId: _selectedCompanyId,
                  initialCompanyName: _selectedCompanyName,
                  onChanged: (id) => _selectedCompanyId = id,
                  onChangedFull: (id, name) {
                    setState(() {
                      _selectedCompanyId = id;
                      _selectedCompanyName = name;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Tanggal & Jam
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _tanggal.isBefore(minDate) ? minDate : _tanggal,
                            firstDate: minDate,
                            lastDate: DateTime(now.year + 1),
                          );
                          if (picked != null) setState(() => _tanggal = picked);
                        },
                        child: InputDecorator(
                          decoration: _inputDecor('Tanggal *', icon: Icons.calendar_today_rounded),
                          child: Text(DateFormat('dd/MM/yyyy').format(_tanggal),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: _waktu);
                          if (picked != null) setState(() => _waktu = picked);
                        },
                        child: InputDecorator(
                          decoration: _inputDecor('Jam *', icon: Icons.access_time_rounded),
                          child: Text(
                            '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Shift
                DropdownButtonFormField<String>(
                  value: _shift,
                  decoration: _inputDecor('Shift Kerja *', icon: Icons.timelapse_rounded),
                  items: const [
                    DropdownMenuItem(value: 'Shift 1 (Siang)', child: Text('Shift 1 (Siang)')),
                    DropdownMenuItem(value: 'Shift 2 (Malam)', child: Text('Shift 2 (Malam)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _shift = val);
                  },
                ),
                const SizedBox(height: 12),

                // Area Tambang (Master Picker)
                InkWell(
                  onTap: _showAreaPicker,
                  child: IgnorePointer(
                    child: TextFormField(
                      controller: _areaCtrl,
                      decoration: _inputDecor(
                        'Area Tambang *',
                        icon: Icons.map_rounded,
                        suffixIcon: _isLoadingAreas
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib pilih area' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Disposal Area (Picker with custom typing support)
                InkWell(
                  onTap: _showDisposalPicker,
                  child: IgnorePointer(
                    child: TextFormField(
                      controller: _disposalCtrl,
                      decoration: _inputDecor(
                        'Nama Disposal *',
                        icon: Icons.terrain_rounded,
                        suffixIcon: _isLoadingDisposals
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib isi nama disposal' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nama Dump
                TextFormField(
                  controller: _namaDumpCtrl,
                  decoration: _inputDecor(
                    'Nama Dump *',
                    hint: 'Contoh: Dump Pit 1 Alpha, Waste Dump RL 120',
                    icon: Icons.landscape_rounded,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Wajib isi nama dump' : null,
                ),
                const SizedBox(height: 12),

                // Nama Pad / Timbunan
                TextFormField(
                  controller: _padCtrl,
                  decoration: _inputDecor(
                    'Nama Pad / Timbunan',
                    hint: 'Contoh: Pad 2B, Pad RL 45, Crest Timur',
                    icon: Icons.layers_rounded,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _detilLokasiCtrl,
                  decoration: _inputDecor('Detil Lokasi / Elevasi (RL)', icon: Icons.tag_rounded),
                ),
                const SizedBox(height: 12),

                SapGpsLocationCard(
                  latController: _latCtrl,
                  lngController: _lngCtrl,
                  lokasiController: _lokasiCtrl,
                  primaryColor: _orangeColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 2: 8 Parameter Teknis Disposal
            _buildSectionCard(
              title: '2. Penilaian 8 Parameter Teknis Disposal',
              icon: Icons.checklist_rounded,
              children: [
                _buildParameterCard(
                  code: 'D01',
                  name: 'Daya Dukung & Kerataan Lantai Dump',
                  weight: '15%',
                  currentScore: _skorLantaiDump,
                  onChanged: (val) => setState(() => _skorLantaiDump = val),
                  options: const [
                    _ParamOption(100, 'Sangat Baik', 'Lantai padat sempurna, rata, tidak ada amblas/undulasi ban'),
                    _ParamOption(70, 'Cukup', 'Cukup padat, ada bekas jejak ban dangkal (<10cm)'),
                    _ParamOption(40, 'Kurang', 'Lembek, amblas ban >15cm, bergelombang, butuh dozer grading'),
                    _ParamOption(0, 'Kritis', 'Lumpur parah / unit hauling amblas terjebak (Stop dumping)'),
                  ],
                ),
                _buildParameterCard(
                  code: 'D02',
                  name: 'Tanggul Pengaman (Safety Berm)',
                  weight: '15%',
                  currentScore: _skorSafetyBerm,
                  onChanged: (val) => setState(() => _skorSafetyBerm = val),
                  options: const [
                    _ParamOption(100, 'Sangat Baik', 'Tinggi >= 3/4 diameter ban unit terbesar, padat, tegak & rapi'),
                    _ParamOption(70, 'Cukup', 'Tinggi 1/2 - 3/4 diameter ban, perlu penambahan material'),
                    _ParamOption(40, 'Kurang', 'Tinggi < 1/2 diameter ban, terputus-putus atau rapuh'),
                    _ParamOption(0, 'Kritis', 'Tidak ada tanggul sama sekali / roboh total (Kritis!)'),
                  ],
                ),
                _buildParameterCard(
                  code: 'D03',
                  name: 'Kondisi Crest & Tepi Dumping',
                  weight: '15%',
                  currentScore: _skorKondisiCrest,
                  onChanged: (val) => setState(() => _skorKondisiCrest = val),
                  options: const [
                    _ParamOption(100, 'Sangat Baik', 'Stabil, tidak ada retakan (crack), jarak aman dumping terjaga'),
                    _ParamOption(70, 'Cukup', 'Ada retakan rambut minor (<2cm), lereng stabil'),
                    _ParamOption(40, 'Kurang', 'Retakan aktif (tension crack >5cm), potensi longsor crest'),
                    _ParamOption(0, 'Kritis', 'Terjadi runtuhan / crest failure aktif (Area bahaya terlarang)'),
                  ],
                ),
                _buildParameterCard(
                  code: 'D04',
                  name: 'Counter Grade Lantai Dump',
                  weight: '15%',
                  currentScore: _skorGradeDumping,
                  onChanged: (val) => setState(() => _skorGradeDumping = val),
                  options: const [
                    _ParamOption(100, 'Sangat Baik', 'Counter grade 2% - 3% ke arah dalam (menjauhi crest) sempurna'),
                    _ParamOption(70, 'Cukup', 'Counter grade tipis (1% - 2%), air tidak mengalir ke crest'),
                    _ParamOption(40, 'Kurang', 'Rata 0% (datar), tidak ada kemiringan penahan mundur'),
                    _ParamOption(0, 'Kritis', 'Minus grade (miring ke arah jurang/crest - Sangat Berbahaya)'),
                  ],
                ),
                _buildParameterCard(
                  code: 'D05',
                  name: 'Drainase & Saluran Air Dump',
                  weight: '10%',
                  currentScore: _skorDrainaseDump,
                  onChanged: (val) => setState(() => _skorDrainaseDump = val),
                  options: const [
                    _ParamOption(100, 'Sangat Baik', 'Parit & tali air aktif, tidak ada genangan di lantai dump'),
                    _ParamOption(70, 'Cukup', 'Ada genangan kecil setempat, air cepat meresap/mengalir'),
                    _ParamOption(40, 'Kurang', 'Genangan air meluas di area dumping, saluran tersumbat'),
                    _ParamOption(0, 'Kritis', 'Tergenang air dalam, mengikis tanggul/crest disposal'),
                  ],
                ),
                _buildParameterCard(
                  code: 'D06',
                  name: 'Penataan Spillage & Kebersihan',
                  weight: '10%',
                  currentScore: _skorPenataanSpillage,
                  onChanged: (val) => setState(() => _skorPenataanSpillage = val),
                  options: const [
                    _ParamOption(100, 'Sangat Baik', 'Area bersih dari tumpahan batuan besar, jalur manuver bersih'),
                    _ParamOption(70, 'Cukup', 'Ada sedikit spillage batuan kecil di tepi yang aman'),
                    _ParamOption(40, 'Kurang', 'Batuan besar berserakan di jalur manuver / area dumping'),
                    _ParamOption(0, 'Kritis', 'Spillage parah menghalangi manuver dan merusak ban unit'),
                  ],
                ),
                _buildParameterCard(
                  code: 'D07',
                  name: 'Rambu K3 & Lampu Penerangan',
                  weight: '10%',
                  currentScore: _skorRambuPenerangan,
                  onChanged: (val) => setState(() => _skorRambuPenerangan = val),
                  options: const [
                    _ParamOption(100, 'Sangat Baik', 'Rambu batas dumping, batas mundur, tower lamp terang & jelas'),
                    _ParamOption(70, 'Cukup', 'Rambu lengkap namun sedikit kotor, pencahayaan cukup'),
                    _ParamOption(40, 'Kurang', 'Rambu rusak/kurang lengkap, lampu penerangan redup/mati'),
                    _ParamOption(0, 'Kritis', 'Tanpa rambu dan gelap gulita pada malam hari'),
                  ],
                ),
                _buildParameterCard(
                  code: 'D08',
                  name: 'Spotter & Pola Manuver Unit',
                  weight: '10%',
                  currentScore: _skorSpotterManuver,
                  onChanged: (val) => setState(() => _skorSpotterManuver = val),
                  options: const [
                    _ParamOption(100, 'Sangat Baik', 'Spotter aktif bersertifikat, rompi reflektif, pandu sesuai SOP'),
                    _ParamOption(70, 'Cukup', 'Spotter standby namun koordinasi manuver perlu ditingkatkan'),
                    _ParamOption(40, 'Kurang', 'Spotter tidak di posisi aman / radio komunikasi terganggu'),
                    _ParamOption(0, 'Kritis', 'Tanpa spotter pada kondisi kritis / unit manuver liar'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 3: Catatan, Tindakan, PIC & Foto Dokumentasi
            _buildSectionCard(
              title: '3. Foto Dokumentasi & Tindakan',
              icon: Icons.camera_enhance_rounded,
              children: [
                // 1. Catatan Observasi Kondisi Disposal
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
                          Icon(Icons.notes_rounded, size: 16, color: _orangeColor),
                          SizedBox(width: 8),
                          Text(
                            'Catatan Observasi Kondisi Disposal',
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
                          hintText: 'Tuliskan observasi kondisi aktual lantai, lereng, crest atau tanggul...',
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
                          Icon(Icons.handyman_rounded, size: 16, color: _orangeColor),
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
                          hintText: 'Contoh: Dozer grading segera, perbaikan safety berm, perbaikan parit...',
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
                        Icon(Icons.person_pin_circle_rounded, size: 16, color: _orangeColor),
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
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedPicEmployee != null || _picCtrl.text.isNotEmpty
                                ? _orangeColor
                                : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_selectedPicEmployee != null)
                              _DciEmployeeAvatar(
                                photo: _selectedPicEmployee!.foto,
                                name: _selectedPicEmployee!.nama,
                                nik: _selectedPicEmployee!.nik,
                                radius: 22,
                                fallbackBg: const Color(0xFFFED7AA),
                                fallbackFg: _orangeColor,
                              )
                            else if (_picCtrl.text.isNotEmpty)
                              _DciEmployeeAvatar(
                                photo: null,
                                name: _picCtrl.text,
                                nik: '',
                                radius: 22,
                                fallbackBg: const Color(0xFFFED7AA),
                                fallbackFg: _orangeColor,
                              )
                            else
                              const CircleAvatar(
                                radius: 22,
                                backgroundColor: Color(0xFFFFF7ED),
                                child: Icon(
                                  Icons.person_search_rounded,
                                  color: _orangeColor,
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
                                          ? const Color(0xFF9A3412)
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
                                          ? const Color(0xFFC2410C)
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

                // 4. Foto Dokumentasi Kondisi Disposal
                const Row(
                  children: [
                    Icon(Icons.photo_camera_back_rounded, size: 16, color: _orangeColor),
                    SizedBox(width: 8),
                    Text(
                      'Foto Dokumentasi Kondisi Disposal',
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
                                        Text('Foto Dokumentasi Disposal', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                        Icon(Icons.cached_rounded, color: Color(0xFFFED7AA), size: 14),
                                        SizedBox(width: 4),
                                        Text('Ganti Foto', style: TextStyle(color: Color(0xFFFED7AA), fontSize: 11, fontWeight: FontWeight.bold)),
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
                            color: _orangeColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_a_photo_rounded, color: _orangeColor, size: 24),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Unggah Bukti Foto Kondisi Disposal',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Lampirkan foto kondisi aktual lereng, crest, safety berm, atau drainase (JPG/PNG)',
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
                                  backgroundColor: _orangeColor,
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
                                icon: const Icon(Icons.photo_library_rounded, size: 16, color: _orangeColor),
                                label: const Text('Galeri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _orangeColor)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _orangeColor, width: 1.2),
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
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orangeColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Menyimpan Laporan DCI...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_rounded, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            widget.editData != null ? 'Perbarui Laporan DCI' : 'Simpan Inspeksi DCI',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Live Score Card Widget
  Widget _buildLiveScoreCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _categoryColor.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: _categoryColor.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _categoryColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${_totalScore.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _categoryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Score: ${_totalScore.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _categoryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _kategoriIndex.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _kategoriIndex == 'Baik'
                      ? 'Area dumping memenuhi standar SOP teknis & aman beroperasi.'
                      : (_kategoriIndex == 'Sedang'
                          ? 'Perlu perhatian pengawas & perbaikan minor (grading/berm).'
                          : 'Kondisi berisiko tinggi. Wajib tindakan perbaikan segera!'),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section Wrapper Card
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _orangeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  // Parameter Card with Choice Chips
  Widget _buildParameterCard({
    required String code,
    required String name,
    required String weight,
    required int currentScore,
    required ValueChanged<int> onChanged,
    required List<_ParamOption> options,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _orangeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  code,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _orangeColor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(weight, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...options.map((opt) {
            final isSelected = currentScore == opt.score;
            final Color optColor = opt.score == 100
                ? const Color(0xFF10B981)
                : (opt.score == 70
                    ? const Color(0xFFF59E0B)
                    : (opt.score == 40 ? const Color(0xFFF97316) : const Color(0xFFEF4444)));

            return InkWell(
              onTap: () => onChanged(opt.score),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? optColor.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? optColor : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? optColor : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${opt.score}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? optColor : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            opt.desc,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected) Icon(Icons.check_circle_rounded, color: optColor, size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  InputDecoration _inputDecor(
    String label, {
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: _orangeColor, size: 20) : null,
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _orangeColor, width: 1.5)),
    );
  }
}

class _ParamOption {
  final int score;
  final String label;
  final String desc;

  const _ParamOption(this.score, this.label, this.desc);
}

class _DciEmployeePickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color themeColor;

  const _DciEmployeePickerSheet({
    required this.title,
    required this.subtitle,
    required this.themeColor,
  });

  @override
  State<_DciEmployeePickerSheet> createState() => _DciEmployeePickerSheetState();
}

class _DciEmployeePickerSheetState extends State<_DciEmployeePickerSheet> {
  final _searchCtrl = TextEditingController();
  final _db = DatabaseService();
  final _api = ApiService();

  List<_DciEmployeeItem> _allLoadedResults = [];
  List<_DciEmployeeItem> _filteredResults = [];
  bool _isLoading = false;
  bool _isOffline = false;
  Timer? _debounce;

  String _userCompany = '';
  int _userCompanyId = 0;
  bool _onlyMyCompany = false;

  @override
  void initState() {
    super.initState();
    final profile = PreferenceService.getProfile();
    _userCompany = (profile?.company ?? '').trim();
    _userCompanyId = profile?.companyId ?? 0;
    _loadEmployees('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    if (_onlyMyCompany) {
      _filteredResults = _allLoadedResults.where((e) {
        if (_userCompanyId > 0 && e.perusahaanId != null && e.perusahaanId == _userCompanyId) return true;
        if (_userCompany.isNotEmpty && e.perusahaan.toLowerCase().contains(_userCompany.toLowerCase())) return true;
        return false;
      }).toList();
    } else {
      _filteredResults = List.from(_allLoadedResults);
    }
  }

  Future<void> _loadEmployees(String q) async {
    final cleanQ = q.trim();
    setState(() => _isLoading = true);

    bool serverOk = false;
    try {
      final serverItems = await _api.searchDciEmployees(
        cleanQ,
        companyId: _userCompanyId > 0 ? _userCompanyId : null,
        companyName: _userCompany.isNotEmpty ? _userCompany : null,
        limit: 80,
      );

      if (serverItems.isNotEmpty) {
        serverOk = true;
        _cacheEmployeesToDb(serverItems);
        if (mounted) {
          setState(() {
            _allLoadedResults = serverItems.map((e) {
              final rawComp = e['perusahaanId'];
              final int? compId = rawComp is int ? rawComp : int.tryParse(rawComp?.toString() ?? '');
              return _DciEmployeeItem(
                nik: e['nik']?.toString().trim() ?? '',
                nama: e['nama']?.toString().trim() ?? '',
                jabatan: (e['jabatan'] ?? e['posisi'])?.toString().trim() ?? 'Staff',
                departemen: (e['departemen'] ?? e['depart'])?.toString().trim() ?? '',
                perusahaan: e['perusahaan']?.toString().trim() ?? '',
                perusahaanId: compId,
                foto: e['foto']?.toString().trim(),
              );
            }).toList();
            _applyFilter();
            _isLoading = false;
            _isOffline = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Offline SQLite Fallback
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
            return _DciEmployeeItem(
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

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.themeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_pin_rounded, color: widget.themeColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari Nama, NIK, jabatan, atau perusahaan...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadEmployees('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Filter Chips: Semua vs Perusahaan Saya
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Semua Karyawan', style: TextStyle(fontSize: 11)),
                    selected: !_onlyMyCompany,
                    selectedColor: widget.themeColor.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: !_onlyMyCompany ? widget.themeColor : const Color(0xFF475569),
                      fontWeight: !_onlyMyCompany ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() {
                        _onlyMyCompany = false;
                        _applyFilter();
                      });
                    },
                  ),
                  if (_userCompany.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('🏢 $_userCompany', style: const TextStyle(fontSize: 11)),
                      selected: _onlyMyCompany,
                      selectedColor: const Color(0xFFDCFCE7),
                      labelStyle: TextStyle(
                        color: _onlyMyCompany ? const Color(0xFF166534) : const Color(0xFF475569),
                        fontWeight: _onlyMyCompany ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _onlyMyCompany = true;
                          _applyFilter();
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),

            if (_isOffline) ...[
              const SizedBox(height: 6),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Mode Offline: Menggunakan data tersimpan lokal',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Results List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: widget.themeColor, strokeWidth: 2.5),
                    )
                  : _filteredResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text(
                                _searchCtrl.text.isEmpty
                                    ? 'Ketik nama / NIK untuk mencari'
                                    : 'Karyawan "${_searchCtrl.text}" tidak ditemukan',
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (ctx, i) {
                            final emp = _filteredResults[i];
                            final isMyCompany = (_userCompanyId > 0 && emp.perusahaanId == _userCompanyId) ||
                                (_userCompany.isNotEmpty && emp.perusahaan.toLowerCase().contains(_userCompany.toLowerCase()));

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: _DciEmployeeAvatar(
                                photo: emp.foto,
                                name: emp.nama,
                                nik: emp.nik,
                                radius: 20,
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      emp.nama,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                    ),
                                  ),
                                  if (isMyCompany) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
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
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    '${emp.nik} • ${emp.jabatan.isNotEmpty ? emp.jabatan : "Staff"}${emp.departemen.isNotEmpty ? " • ${emp.departemen}" : ""}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                  ),
                                  Text(
                                    emp.perusahaan.isNotEmpty ? emp.perusahaan : 'Mitra',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                              onTap: () => Navigator.pop(context, emp),
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

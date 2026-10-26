import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';
import 'gci_model.dart';

class _GciEmployeeItem {
  final String nik;
  final String nama;
  final String departemen;
  final String jabatan;
  final String perusahaan;
  final int? perusahaanId;
  final String? foto;

  _GciEmployeeItem({
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

class _GciEmployeeAvatar extends StatefulWidget {
  final String? photo;
  final String name;
  final String nik;
  final double radius;
  final Color? fallbackBg;
  final Color? fallbackFg;

  const _GciEmployeeAvatar({
    required this.photo,
    required this.name,
    required this.nik,
    this.radius = 18,
    this.fallbackBg,
    this.fallbackFg,
  });

  @override
  State<_GciEmployeeAvatar> createState() => _GciEmployeeAvatarState();
}

class _GciEmployeeAvatarState extends State<_GciEmployeeAvatar> {
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
  void didUpdateWidget(covariant _GciEmployeeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo || oldWidget.nik != widget.nik) {
      _attempt = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.trim().isNotEmpty ? widget.name.trim()[0].toUpperCase() : 'U';
    final bg = widget.fallbackBg ?? const Color(0xFFF0F9FF);
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

class GciFormPage extends StatefulWidget {
  final GciReportItem? editData;

  const GciFormPage({super.key, this.editData});

  @override
  State<GciFormPage> createState() => _GciFormPageState();
}

class _GciFormPageState extends State<GciFormPage> {
  final _api = ApiService();
  final _db = DatabaseService();
  final _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();

  // Perusahaan & Mitra
  int? _selectedCompanyId;
  String? _selectedCompanyName;

  // Header & Info Umum
  final _judulTemuanCtrl = TextEditingController();
  DateTime? _dueDate;
  String _jenisInspeksi = 'Inspeksi Rutin';

  // Waktu & Lokasi
  late DateTime _tanggal;
  late TimeOfDay _waktu;
  final _areaCtrl = TextEditingController();
  final _lokasiCtrl = TextEditingController();
  final _detilLokasiCtrl = TextEditingController();
  final _pitCtrl = TextEditingController();
  final _namaLerengCtrl = TextEditingController();
  String _areaType = 'Highwall';
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  String _shift = 'Shift 1 (Siang)';

  // 8 Parameters GCI (100, 75, 50, 25, 0)
  int _skorGeometriLereng = 100;
  int _skorKondisiCrestToe = 100;
  int _skorTensionCrack = 100;
  int _skorKestabilanBatuan = 100;
  int _skorRembesanDrainase = 100;
  int _skorPemantauanSensor = 100;
  int _skorDemarkasiZona = 100;
  int _skorKepatuhanRekomendasi = 100;

  // Catatan, Tindakan, PIC, PJA, Foto
  final _catatanCtrl = TextEditingController();
  final _tindakanCtrl = TextEditingController();
  final _picCtrl = TextEditingController();
  final _picNikCtrl = TextEditingController();
  final _pjaNamaCtrl = TextEditingController();
  final _pjaNikCtrl = TextEditingController();
  _GciEmployeeItem? _selectedPicEmployee;
  _GciEmployeeItem? _selectedPjaEmployee;
  File? _fotoFile;
  String? _existingFotoUrl;

  bool _isSaving = false;

  // Recommendations from Database
  List<String> _masterPits = [];
  List<String> _masterAreas = [];
  List<String> _masterNamaLerengs = [];
  bool _isLoadingAreas = false;

  static const _blueColor = Color(0xFF0284C7);
  static const _blueGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const _areaTypeOptions = [
    'Highwall',
    'Lowwall',
    'Sidewall',
    'Bench/Jenjang',
    'Disposal Slope',
    'In-Pit Dump',
    'Stockpile Embankment',
    'Sump Slope'
  ];

  static const _jenisInspeksiOptions = [
    'Inspeksi Rutin',
    'Inspeksi Pasca Hujan',
    'Inspeksi Pasca Peledakan',
    'Inspeksi Perubahan Geometri',
    'Inspeksi Khusus',
    'Re-Inspection'
  ];

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

      _judulTemuanCtrl.text = d.judulTemuan ?? '';
      _dueDate = d.dueDate;
      _jenisInspeksi = d.jenisInspeksi ?? 'Inspeksi Rutin';

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
      _pitCtrl.text = d.pit ?? '';
      _namaLerengCtrl.text = d.namaLereng ?? '';
      _areaType = d.areaType ?? 'Highwall';
      _latCtrl.text = d.latitude ?? '';
      _lngCtrl.text = d.longitude ?? '';
      _shift = d.shift ?? 'Shift 1 (Siang)';

      _skorGeometriLereng = d.skorGeometriLereng;
      _skorKondisiCrestToe = d.skorKondisiCrestToe;
      _skorTensionCrack = d.skorTensionCrack;
      _skorKestabilanBatuan = d.skorKestabilanBatuan;
      _skorRembesanDrainase = d.skorRembesanDrainase;
      _skorPemantauanSensor = d.skorPemantauanSensor;
      _skorDemarkasiZona = d.skorDemarkasiZona;
      _skorKepatuhanRekomendasi = d.skorKepatuhanRekomendasi;

      _catatanCtrl.text = d.catatan ?? '';
      _tindakanCtrl.text = d.tindakanPerbaikan ?? '';
      _picCtrl.text = d.pic ?? '';
      _picNikCtrl.text = d.picNik ?? '';
      _pjaNamaCtrl.text = d.pjaNama ?? '';
      _pjaNikCtrl.text = d.pjaNik ?? '';
      _existingFotoUrl = d.fotoUrl;
    }

    _loadAreas();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _judulTemuanCtrl.dispose();
    _areaCtrl.dispose();
    _lokasiCtrl.dispose();
    _detilLokasiCtrl.dispose();
    _pitCtrl.dispose();
    _namaLerengCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _catatanCtrl.dispose();
    _tindakanCtrl.dispose();
    _picCtrl.dispose();
    _picNikCtrl.dispose();
    _pjaNamaCtrl.dispose();
    _pjaNikCtrl.dispose();
    super.dispose();
  }

  // Live Score Calculation
  double get _totalScore {
    final s = (_skorGeometriLereng * 0.15) +
        (_skorKondisiCrestToe * 0.15) +
        (_skorTensionCrack * 0.15) +
        (_skorKestabilanBatuan * 0.15) +
        (_skorRembesanDrainase * 0.10) +
        (_skorPemantauanSensor * 0.10) +
        (_skorDemarkasiZona * 0.10) +
        (_skorKepatuhanRekomendasi * 0.10);
    return double.parse(s.toStringAsFixed(1));
  }

  String get _kategoriIndex {
    if (_totalScore >= 80) return 'Baik';
    if (_totalScore >= 65) return 'Sedang';
    return 'Kurang';
  }

  int get _minParamScore {
    final scores = [
      _skorGeometriLereng,
      _skorKondisiCrestToe,
      _skorTensionCrack,
      _skorKestabilanBatuan,
      _skorRembesanDrainase,
      _skorPemantauanSensor,
      _skorDemarkasiZona,
      _skorKepatuhanRekomendasi,
    ];
    return scores.reduce((curr, next) => curr < next ? curr : next);
  }

  String get _tarpLevel {
    final minVal = _minParamScore;
    if (minVal <= 40 || _totalScore < 50) return 'RED';
    if (minVal <= 60 || _totalScore < 70) return 'ORANGE';
    if (minVal <= 75 || _totalScore < 85) return 'YELLOW';
    return 'GREEN';
  }

  Color get _tarpColor {
    switch (_tarpLevel) {
      case 'RED':
        return const Color(0xFFEF4444);
      case 'ORANGE':
        return const Color(0xFFEA580C);
      case 'YELLOW':
        return const Color(0xFFEAB308);
      default:
        return const Color(0xFF10B981);
    }
  }

  Future<void> _loadAreas() async {
    setState(() => _isLoadingAreas = true);
    try {
      final sqldb = await _db.database;
      final localAreas = await sqldb.rawQuery(
        "SELECT DISTINCT area_utama FROM tbl_m_benchmark WHERE area_utama IS NOT NULL AND area_utama != '' ORDER BY area_utama",
      );

      if (localAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = localAreas.map((e) => e['area_utama'].toString()).toList();
        });
      }

      final serverAreas = await _api.getMasterAreas(perusahaanId: PreferenceService.getProfile()?.companyId);
      if (serverAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = serverAreas;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingAreas = false);
  }

  Future<void> _loadSuggestions() async {
    try {
      final sqldb = await _db.database;
      final localRows = await sqldb.rawQuery(
        "SELECT DISTINCT pit, area, nama_lereng FROM tbl_t_gci_report WHERE (pit IS NOT NULL AND pit != '') OR (nama_lereng IS NOT NULL AND nama_lereng != '')",
      );

      final lPits = <String>{};
      final lAreas = <String>{};
      final lLerengs = <String>{};
      for (final r in localRows) {
        final p = r['pit']?.toString();
        final a = r['area']?.toString();
        final l = r['nama_lereng']?.toString();
        if (p != null && p.trim().isNotEmpty) lPits.add(p.trim());
        if (a != null && a.trim().isNotEmpty) lAreas.add(a.trim());
        if (l != null && l.trim().isNotEmpty) lLerengs.add(l.trim());
      }

      if (mounted) {
        setState(() {
          _masterPits = lPits.toList()..sort();
          _masterNamaLerengs = lLerengs.toList()..sort();
        });
      }

      final res = await _api.getGciSuggestions();
      res.fold((l) => null, (r) {
        if (mounted) {
          final sPits = (r['pits'] as List?)?.map((e) => e.toString()).toList() ?? [];
          final sAreas = (r['areas'] as List?)?.map((e) => e.toString()).toList() ?? [];
          final sLerengs = (r['lerengs'] as List?)?.map((e) => e.toString()).toList() ?? [];

          setState(() {
            _masterPits = {..._masterPits, ...sPits}.toList()..sort();
            _masterAreas = {..._masterAreas, ...sAreas}.toList()..sort();
            _masterNamaLerengs = {..._masterNamaLerengs, ...sLerengs}.toList()..sort();
          });
        }
      });
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() {
          _fotoFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e')),
        );
      }
    }
  }

  // ==================== Target SAP Employee Picker Modal ====================
  Future<_GciEmployeeItem?> _openEmployeePicker({
    required String title,
    required String subtitle,
    required Color themeColor,
  }) {
    return showModalBottomSheet<_GciEmployeeItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GciEmployeePickerSheet(
        title: title,
        subtitle: subtitle,
        themeColor: themeColor,
      ),
    );
  }

  void _chooseEmployee({required bool isPja}) async {
    final emp = await _openEmployeePicker(
      title: isPja ? 'Pilih Supervisor Geoteknik (PJA)' : 'Pilih PIC',
      subtitle: isPja
          ? 'Pengawas / PJA penanggung jawab geoteknik'
          : 'Pilih penanggung jawab mitigasi',
      themeColor: _blueColor,
    );
    if (emp != null && mounted) {
      setState(() {
        if (isPja) {
          _selectedPjaEmployee = emp;
          _pjaNamaCtrl.text = '${emp.nama} (${emp.nik})';
          _pjaNikCtrl.text = emp.nik;
        } else {
          _selectedPicEmployee = emp;
          _picCtrl.text = '${emp.nama} (${emp.nik})';
          _picNikCtrl.text = emp.nik;
        }
      });
    }
  }

  void _showAreaPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _masterAreas.where((a) => a.toLowerCase().contains(filter.toLowerCase())).toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Pilih Area Sektor Tambang (${filtered.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari area...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setModalState(() => filter = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Tidak ada data area', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (ctx, i) {
                              final item = filtered[i];
                              final isSelected = _areaCtrl.text == item;
                              return ListTile(
                                title: Text(item, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _blueColor : Colors.black87)),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: _blueColor, size: 20) : null,
                                onTap: () {
                                  setState(() => _areaCtrl.text = item);
                                  Navigator.pop(ctx);
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

  void _showPitPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _masterPits.where((d) => d.toLowerCase().contains(filter.toLowerCase())).toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Pilih Pit Tambang (${filtered.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari pit tambang...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setModalState(() => filter = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Tidak ada data pit', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (ctx, i) {
                              final item = filtered[i];
                              final isSelected = _pitCtrl.text == item;
                              return ListTile(
                                title: Text(item, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _blueColor : Colors.black87)),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: _blueColor, size: 20) : null,
                                onTap: () {
                                  setState(() => _pitCtrl.text = item);
                                  Navigator.pop(ctx);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan lengkapi field yang bertanda bintang (*)')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final profile = PreferenceService.getProfile();
    final userNik = profile?.noNik ?? PreferenceService.getUser() ?? '';
    final userNama = profile?.namaLengkap ?? '';
    final userDept = profile?.depart ?? 'Engineering / Geotech';
    final userCompany = _selectedCompanyName ?? profile?.company ?? 'PT INDEXIM COALINDO';
    final userCompanyId = _selectedCompanyId ?? profile?.companyId ?? 0;

    final dateStr = DateFormat('yyyy-MM-dd').format(_tanggal);
    final timeStr = '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}';
    final dueDateStr = _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null;

    // Pastikan lokasi terisi otomatis dari GPS / nama lereng / detil
    if (_lokasiCtrl.text.trim().isEmpty) {
      if (_latCtrl.text.isNotEmpty && _lngCtrl.text.isNotEmpty) {
        _lokasiCtrl.text = 'GPS: ${_latCtrl.text}, ${_lngCtrl.text}';
      } else if (_detilLokasiCtrl.text.trim().isNotEmpty) {
        _lokasiCtrl.text = _detilLokasiCtrl.text.trim();
      } else if (_namaLerengCtrl.text.trim().isNotEmpty) {
        _lokasiCtrl.text = _namaLerengCtrl.text.trim();
      } else {
        _lokasiCtrl.text = 'Lereng Geoteknik';
      }
    }

    final mapData = <String, dynamic>{
      if (widget.editData != null) 'id': widget.editData!.id.toString(),
      'tanggal': dateStr,
      'waktu': timeStr,
      'nik': userNik,
      'nama': userNama,
      'departemen': userDept,
      'perusahaan': userCompany,
      'perusahaan_id': userCompanyId.toString(),
      'judul_temuan': _judulTemuanCtrl.text.trim().isNotEmpty ? _judulTemuanCtrl.text.trim() : 'Inspeksi ${_areaType} ${_pitCtrl.text}',
      'due_date': dueDateStr,
      'jenis_inspeksi': _jenisInspeksi,
      'pit': _pitCtrl.text.trim(),
      'area': _areaCtrl.text.trim(),
      'nama_lereng': _namaLerengCtrl.text.trim(),
      'area_type': _areaType,
      'lokasi': _lokasiCtrl.text.trim(),
      'detil_lokasi': _detilLokasiCtrl.text.trim(),
      'shift': _shift,
      'latitude': _latCtrl.text.trim(),
      'longitude': _lngCtrl.text.trim(),
      'skor_geometri_lereng': _skorGeometriLereng.toString(),
      'skor_kondisi_crest_toe': _skorKondisiCrestToe.toString(),
      'skor_tension_crack': _skorTensionCrack.toString(),
      'skor_kestabilan_batuan': _skorKestabilanBatuan.toString(),
      'skor_rembesan_drainase': _skorRembesanDrainase.toString(),
      'skor_pemantauan_sensor': _skorPemantauanSensor.toString(),
      'skor_demarkasi_zona': _skorDemarkasiZona.toString(),
      'skor_kepatuhan_rekomendasi': _skorKepatuhanRekomendasi.toString(),
      'manual_tarp_level': _tarpLevel,
      'catatan': _catatanCtrl.text.trim(),
      'tindakan_perbaikan': _tindakanCtrl.text.trim(),
      'pic': _picCtrl.text.trim(),
      'pic_nik': _picNikCtrl.text.trim(),
      'pja_nama': _pjaNamaCtrl.text.trim(),
      'pja_nik': _pjaNikCtrl.text.trim(),
    };

    bool isSavedOnline = false;
    try {
      final formData = FormData.fromMap(mapData);
      if (_fotoFile != null && await _fotoFile!.exists()) {
        final fileName = _fotoFile!.path.split(Platform.pathSeparator).last;
        formData.files.add(MapEntry(
          'foto',
          await MultipartFile.fromFile(_fotoFile!.path, filename: fileName),
        ));
      }

      final res = await _api.saveGciReport(formData);
      res.fold(
        (err) => isSavedOnline = false,
        (success) => isSavedOnline = true,
      );
    } catch (_) {
      isSavedOnline = false;
    }

    if (!isSavedOnline) {
      await _saveOffline(mapData);
    } else {
      _showSuccessDialog('Laporan GCI baru berhasil dikirim dan tersimpan di server.');
    }

    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _saveOffline(Map<String, dynamic> mapData) async {
    try {
      final sqldb = await _db.database;
      await sqldb.insert('tbl_t_gci_report', {
        'tanggal': mapData['tanggal'],
        'waktu': mapData['waktu'],
        'nik': mapData['nik'],
        'nama': mapData['nama'],
        'departemen': mapData['departemen'],
        'perusahaan': mapData['perusahaan'],
        'perusahaan_id': int.tryParse(mapData['perusahaan_id']?.toString() ?? '0'),
        'judul_temuan': mapData['judul_temuan'],
        'due_date': mapData['due_date'],
        'jenis_inspeksi': mapData['jenis_inspeksi'],
        'pit': mapData['pit'],
        'area': mapData['area'],
        'nama_lereng': mapData['nama_lereng'],
        'area_type': mapData['area_type'],
        'lokasi': mapData['lokasi'],
        'detil_lokasi': mapData['detil_lokasi'],
        'shift': mapData['shift'],
        'latitude': mapData['latitude'],
        'longitude': mapData['longitude'],
        'skor_geometri_lereng': int.tryParse(mapData['skor_geometri_lereng']?.toString() ?? '100') ?? 100,
        'skor_kondisi_crest_toe': int.tryParse(mapData['skor_kondisi_crest_toe']?.toString() ?? '100') ?? 100,
        'skor_tension_crack': int.tryParse(mapData['skor_tension_crack']?.toString() ?? '100') ?? 100,
        'skor_kestabilan_batuan': int.tryParse(mapData['skor_kestabilan_batuan']?.toString() ?? '100') ?? 100,
        'skor_rembesan_drainase': int.tryParse(mapData['skor_rembesan_drainase']?.toString() ?? '100') ?? 100,
        'skor_pemantauan_sensor': int.tryParse(mapData['skor_pemantauan_sensor']?.toString() ?? '100') ?? 100,
        'skor_demarkasi_zona': int.tryParse(mapData['skor_demarkasi_zona']?.toString() ?? '100') ?? 100,
        'skor_kepatuhan_rekomendasi': int.tryParse(mapData['skor_kepatuhan_rekomendasi']?.toString() ?? '100') ?? 100,
        'total_score': _totalScore,
        'kategori_index': _kategoriIndex,
        'tarp_level': _tarpLevel,
        'catatan': mapData['catatan'],
        'tindakan_perbaikan': mapData['tindakan_perbaikan'],
        'pic': mapData['pic'],
        'pic_nik': mapData['pic_nik'],
        'pja_nama': mapData['pja_nama'],
        'pja_nik': mapData['pja_nik'],
        'foto_url': _fotoFile?.path,
        'created_at': DateTime.now().toIso8601String(),
      });

      try {
        final localId = 'gci_${DateTime.now().millisecondsSinceEpoch}';
        await OfflineSyncService.instance.enqueue(
          feature: 'gci',
          localId: localId,
          payload: {
            'map': mapData,
            if (_fotoFile != null) 'photoPath': _fotoFile!.path,
          },
        );
      } catch (_) {}

      _showSuccessDialog('Laporan GCI tersimpan secara OFFLINE. Data akan otomatis disinkronkan ke server saat jaringan tersedia.', isOffline: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan offline: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(String message, {bool isOffline = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: (isOffline ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOffline ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
                color: isOffline ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isOffline ? 'Tersimpan Offline!' : 'Berhasil Disimpan!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blueColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
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
      prefixIcon: icon != null
          ? Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
            )
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
        borderSide: const BorderSide(color: _blueColor, width: 1.5),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _blueColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: _blueColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildParamCard({
    required String code,
    required String title,
    required String weight,
    required int currentValue,
    required Function(int) onChanged,
    required List<Map<String, dynamic>> options,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _blueColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(code, style: const TextStyle(color: _blueColor, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Bobot $weight', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: options.map((opt) {
                final val = opt['val'] as int;
                final desc = opt['desc'] as String;
                final isSelected = currentValue == val;

                Color scoreBadgeColor;
                if (val >= 100) {
                  scoreBadgeColor = const Color(0xFF10B981);
                } else if (val >= 75) {
                  scoreBadgeColor = const Color(0xFF0EA5E9);
                } else if (val >= 50) {
                  scoreBadgeColor = const Color(0xFFEAB308);
                } else if (val >= 25) {
                  scoreBadgeColor = const Color(0xFFEA580C);
                } else {
                  scoreBadgeColor = const Color(0xFFEF4444);
                }

                return InkWell(
                  onTap: () => onChanged(val),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _blueColor.withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? _blueColor : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scoreBadgeColor.withOpacity(isSelected ? 1.0 : 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$val',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              color: isSelected ? Colors.white : scoreBadgeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            desc,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? _blueColor : Colors.grey.shade400,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
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
      appBar: TopBar(
        title: widget.editData != null ? 'Edit Inspeksi GCI' : 'Form Inspeksi GCI',
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status Geoteknik (GCI)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _tarpColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _tarpColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            'TARP $_tarpLevel',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: _tarpColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_totalScore%',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blueColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle, color: Colors.white, size: 18),
                label: Text(
                  _isSaving ? 'Menyimpan...' : (widget.editData != null ? 'Perbarui Inspeksi' : 'Simpan Inspeksi GCI'),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: _blueGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: _blueColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.landscape_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Geotechnical Condition Index (GCI)',
                          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Evaluasi Stabilitas Lereng, Crest, Toe, Retakan & Sistem Pemicu TARP',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 1: Informasi Umum & Lokasi Lereng
            _buildSectionCard(
              title: '1. Informasi Umum & Lokasi Lereng',
              icon: Icons.pin_drop_rounded,
              children: [
                // Perusahaan
                Row(
                  children: [
                    const Icon(Icons.business_rounded, color: _blueColor, size: 16),
                    const SizedBox(width: 6),
                    const Text('Perusahaan / Mitra Kerja *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const Spacer(),
                    Text('Default Akun Login', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 8),
                CompanyDropdown(
                  initialCompanyId: _selectedCompanyId,
                  initialCompanyName: _selectedCompanyName,
                  hideLabel: true,
                  onChanged: (id) => _selectedCompanyId = id,
                  onChangedFull: (id, name) {
                    setState(() {
                      _selectedCompanyId = id;
                      _selectedCompanyName = name;
                    });
                  },
                  decoration: _inputDecor('Perusahaan / Mitra Kerja *'),
                ),
                const SizedBox(height: 12),

                // Judul Temuan
                TextFormField(
                  controller: _judulTemuanCtrl,
                  decoration: _inputDecor(
                    'Judul / Nama Temuan Inspeksi *',
                    hint: 'Contoh: Retakan Tarik Crest Pit A, Amblesan Lereng Sektor Utara...',
                    icon: Icons.title_rounded,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul temuan wajib diisi' : null,
                ),
                const SizedBox(height: 12),

                // Jenis Inspeksi & Due Date
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _jenisInspeksi,
                        isExpanded: true,
                        decoration: _inputDecor('Jenis Inspeksi', icon: Icons.assignment_outlined),
                        items: _jenisInspeksiOptions
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _jenisInspeksi = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => _dueDate = picked);
                        },
                        child: InputDecorator(
                          decoration: _inputDecor('Target Due Date', icon: Icons.event_available_rounded),
                          child: Text(
                            _dueDate != null ? DateFormat('dd/MM/yyyy').format(_dueDate!) : 'Pilih Tanggal',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Waktu & Tanggal
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final minDate = widget.editData != null && widget.editData!.tanggal.isBefore(today)
                              ? widget.editData!.tanggal
                              : today;
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _tanggal.isBefore(minDate) ? minDate : _tanggal,
                            firstDate: minDate,
                            lastDate: DateTime(now.year + 2),
                          );
                          if (picked != null) setState(() => _tanggal = picked);
                        },
                        child: InputDecorator(
                          decoration: _inputDecor('Tanggal *', icon: Icons.calendar_today_rounded),
                          child: Text(DateFormat('dd/MM/yyyy').format(_tanggal),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                  isExpanded: true,
                  decoration: _inputDecor('Shift Kerja *', icon: Icons.timelapse_rounded),
                  items: const [
                    DropdownMenuItem(value: 'Shift 1 (Siang)', child: Text('Shift 1 (Siang)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Shift 2 (Malam)', child: Text('Shift 2 (Malam)', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _shift = val);
                  },
                ),
                const SizedBox(height: 12),

                // Area Utama & Pit
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _showAreaPicker,
                        child: IgnorePointer(
                          child: TextFormField(
                            controller: _areaCtrl,
                            decoration: _inputDecor(
                              'Area Sektor *',
                              icon: Icons.map_rounded,
                              suffixIcon: _isLoadingAreas
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Wajib pilih area' : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _showPitPicker,
                        child: IgnorePointer(
                          child: TextFormField(
                            controller: _pitCtrl,
                            decoration: _inputDecor(
                              'Pit Tambang *',
                              icon: Icons.terrain_rounded,
                              suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Wajib pilih pit' : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tipe Lereng & Nama Lereng
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _areaType,
                        isExpanded: true,
                        decoration: _inputDecor('Tipe Lereng *', icon: Icons.category_rounded),
                        items: _areaTypeOptions
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _areaType = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _namaLerengCtrl,
                        decoration: _inputDecor('Nama Lereng / RL', hint: 'Contoh: HW Ramp 2, RL 60', icon: Icons.layers_rounded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Keterangan Tambahan / Detil Akses Lereng
                TextFormField(
                  controller: _detilLokasiCtrl,
                  decoration: _inputDecor(
                    'Detil Akses / Rambu Sekitar (Opsional)',
                    hint: 'Contoh: Sebelah utara Sump Pit A, Dekat Ramp 02...',
                    icon: Icons.tag_rounded,
                  ),
                ),
                const SizedBox(height: 12),

                // Koordinat Lokasi Lereng (GPS Akurat)
                SapGpsLocationCard(
                  latController: _latCtrl,
                  lngController: _lngCtrl,
                  lokasiController: _lokasiCtrl,
                  primaryColor: _blueColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 2: 8 Parameter Teknis Geoteknik
            _buildSectionCard(
              title: '2. Penilaian 8 Parameter Geoteknik (GCI)',
              icon: Icons.checklist_rounded,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _tarpColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TARP $_tarpLevel (${_totalScore.toStringAsFixed(0)}%)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: _tarpColor),
                ),
              ),
              children: [
                _buildParamCard(
                  code: 'GEO-01',
                  title: 'Geometri & Kemiringan Lereng (Slope Geometry)',
                  weight: '15%',
                  currentValue: _skorGeometriLereng,
                  onChanged: (v) => setState(() => _skorGeometriLereng = v),
                  options: const [
                    {'val': 100, 'desc': 'Sesuai desain pit geoteknik, sudut aman & lereng rapi'},
                    {'val': 75, 'desc': 'Kemiringan agak curam setempat, masih dalam batas toleransi'},
                    {'val': 50, 'desc': 'Terdapat overbreak atau lereng lebih curam dari desain'},
                    {'val': 25, 'desc': 'Under-cutting / penggalian liar di bawah lereng'},
                    {'val': 0, 'desc': 'Lereng menggantung (overhang) / sangat kritis runtuh'},
                  ],
                ),
                _buildParamCard(
                  code: 'GEO-02',
                  title: 'Kondisi Crest, Toe & Catch Berm',
                  weight: '15%',
                  currentValue: _skorKondisiCrestToe,
                  onChanged: (v) => setState(() => _skorKondisiCrestToe = v),
                  options: const [
                    {'val': 100, 'desc': 'Crest stabil, toe bersih bebas timbunan material runtuhan'},
                    {'val': 75, 'desc': 'Erosi minor pada crest, catch berm masih berfungsi'},
                    {'val': 50, 'desc': 'Catch berm mulai terisi spillage batuan lepas >50%'},
                    {'val': 25, 'desc': 'Toe terdorong / heaving atau catch berm hilang'},
                    {'val': 0, 'desc': 'Crest runtuh masif / toe mengalami deformasi berat'},
                  ],
                ),
                _buildParamCard(
                  code: 'GEO-03',
                  title: 'Bebas Retakan Tarik & Amblesan (Tension Crack)',
                  weight: '15%',
                  currentValue: _skorTensionCrack,
                  onChanged: (v) => setState(() => _skorTensionCrack = v),
                  options: const [
                    {'val': 100, 'desc': 'Tidak ada retakan sama sekali di permukaan maupun crest'},
                    {'val': 75, 'desc': 'Retakan rambut tipis (< 1 cm), tidak ada pergerakan'},
                    {'val': 50, 'desc': 'Retakan terbuka 1 - 5 cm, tanpa amblesan vertikal'},
                    {'val': 25, 'desc': 'Retakan aktif terbuka > 5 cm dan terdapat step down'},
                    {'val': 0, 'desc': 'Retakan masif bercabang / bidang gelincir aktif terlihat'},
                  ],
                ),
                _buildParamCard(
                  code: 'GEO-04',
                  title: 'Kestabilan Batuan & Bahaya Rockfall',
                  weight: '15%',
                  currentValue: _skorKestabilanBatuan,
                  onChanged: (v) => setState(() => _skorKestabilanBatuan = v),
                  options: const [
                    {'val': 100, 'desc': 'Batuan kompak, tidak ada batu lepas/gantung di lereng'},
                    {'val': 75, 'desc': 'Sedikit kerikil lepas, tidak membahayakan jalan tambang'},
                    {'val': 50, 'desc': 'Bongkahan batu lepas (hang boulder) perlu scaling manual'},
                    {'val': 25, 'desc': 'Sering terjadi guguran batu kecil saat operasional'},
                    {'val': 0, 'desc': 'Rockfall aktif terus-menerus / blok batuan raksasa gantung'},
                  ],
                ),
                _buildParamCard(
                  code: 'HYD-01',
                  title: 'Kontrol Rembesan Air & Drainase Lereng',
                  weight: '10%',
                  currentValue: _skorRembesanDrainase,
                  onChanged: (v) => setState(() => _skorRembesanDrainase = v),
                  options: const [
                    {'val': 100, 'desc': 'Muka lereng kering sempurna, saluran drainase atas lancar'},
                    {'val': 75, 'desc': 'Muka lereng lembab, rembesan air minimal tanpa erosi'},
                    {'val': 50, 'desc': 'Rembesan air mengalir membawa butiran pasir/lumpur halus'},
                    {'val': 25, 'desc': 'Piping aktif / saluran air atas meluap mengikis lereng'},
                    {'val': 0, 'desc': 'Saturasi air penuh, lereng bubur lumpur mencair (liquefaction)'},
                  ],
                ),
                _buildParamCard(
                  code: 'MON-01',
                  title: 'Pemantauan Sensor & Tren Pergerakan',
                  weight: '10%',
                  currentValue: _skorPemantauanSensor,
                  onChanged: (v) => setState(() => _skorPemantauanSensor = v),
                  options: const [
                    {'val': 100, 'desc': 'Prisma/Radar/Extensometer stabil, velocity pergerakan 0 mm'},
                    {'val': 75, 'desc': 'Fluktuasi sensor normal musiman dalam batas ambang'},
                    {'val': 50, 'desc': 'Laju regangan pergerakan meningkat perlahan (Linear)'},
                    {'val': 25, 'desc': 'Percepatan pergerakan terdeteksi (Regressive/Accelerating)'},
                    {'val': 0, 'desc': 'Alarm TARP Radar/Extensometer berbunyi terus menerus'},
                  ],
                ),
                _buildParamCard(
                  code: 'CTL-01',
                  title: 'Demarkasi Exclusion Zone & Akses Aman',
                  weight: '10%',
                  currentValue: _skorDemarkasiZona,
                  onChanged: (v) => setState(() => _skorDemarkasiZona = v),
                  options: const [
                    {'val': 100, 'desc': 'Batas radius bahaya terpasang pita/barikade & rambu jelas'},
                    {'val': 75, 'desc': 'Barikade lengkap, papan informasi perlu perapihan'},
                    {'val': 50, 'desc': 'Garis demarkasi terlalu dekat dengan potensi jatuhan batu'},
                    {'val': 25, 'desc': 'Pita demarkasi putus / unit masih mendekati area bahaya'},
                    {'val': 0, 'desc': 'Tanpa barikade pengaman di area lereng tidak stabil'},
                  ],
                ),
                _buildParamCard(
                  code: 'CTL-02',
                  title: 'Kepatuhan Rekomendasi Geoteknik',
                  weight: '10%',
                  currentValue: _skorKepatuhanRekomendasi,
                  onChanged: (v) => setState(() => _skorKepatuhanRekomendasi = v),
                  options: const [
                    {'val': 100, 'desc': '100% rekomendasi teknis & SOP geoteknik ditaati penuh'},
                    {'val': 75, 'desc': 'Rekomendasi sedang dalam proses pengerjaan di lapangan'},
                    {'val': 50, 'desc': 'Implementasi rekomendasi tertunda karena alat produksi'},
                    {'val': 25, 'desc': 'Instruksi larangan mendekat diabaikan oleh operasional'},
                    {'val': 0, 'desc': 'Pelanggaran fatal terhadap batas rekomendasi geoteknik'},
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 3: Catatan, Tindakan, PIC, PJA & Foto Dokumentasi
            _buildSectionCard(
              title: '3. Foto Dokumentasi, Tindakan & PIC Penanggung Jawab',
              icon: Icons.camera_enhance_rounded,
              children: [
                // 1. Catatan Observasi
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
                            'Catatan Observasi Kondisi Lereng Tambang',
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
                          hintText: 'Tuliskan deskripsi visual batuan, retakan tarik, atau rembesan air lereng...',
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

                // 2. Rekomendasi Tindakan Mitigasi
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
                            'Rekomendasi Tindakan Mitigasi Geoteknik',
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
                          hintText: 'Contoh: Scaling batuan lepas, pasang pita exclusion zone, kurangi beban crest...',
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

                // 3. PIC Penanggung Jawab Mitigasi (Target SAP)
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
                      onTap: () => _chooseEmployee(isPja: false),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedPicEmployee != null || _picCtrl.text.isNotEmpty
                              ? const Color(0xFFF0F9FF)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedPicEmployee != null || _picCtrl.text.isNotEmpty
                                ? _blueColor
                                : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_selectedPicEmployee != null)
                              _GciEmployeeAvatar(
                                photo: _selectedPicEmployee!.foto,
                                name: _selectedPicEmployee!.nama,
                                nik: _selectedPicEmployee!.nik,
                                radius: 22,
                                fallbackBg: const Color(0xFFBAE6FD),
                                fallbackFg: _blueColor,
                              )
                            else if (_picCtrl.text.isNotEmpty)
                              _GciEmployeeAvatar(
                                photo: null,
                                name: _picCtrl.text,
                                nik: '',
                                radius: 22,
                                fallbackBg: const Color(0xFFBAE6FD),
                                fallbackFg: _blueColor,
                              )
                            else
                              const CircleAvatar(
                                radius: 22,
                                backgroundColor: Color(0xFFF0F9FF),
                                child: Icon(
                                  Icons.person_search_rounded,
                                  color: _blueColor,
                                  size: 24,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedPicEmployee?.nama ??
                                        (_picCtrl.text.isNotEmpty ? _picCtrl.text : 'Pilih PIC'),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: _selectedPicEmployee != null || _picCtrl.text.isNotEmpty
                                          ? const Color(0xFF0369A1)
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
                                          ? const Color(0xFF0284C7)
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
                                    _picNikCtrl.clear();
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
                const SizedBox(height: 14),

                // 4. Supervisor Geoteknik (PJA)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.supervisor_account_rounded, size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'Supervisor Geoteknik (PJA)',
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
                      onTap: () => _chooseEmployee(isPja: true),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedPjaEmployee != null || _pjaNamaCtrl.text.isNotEmpty
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedPjaEmployee != null || _pjaNamaCtrl.text.isNotEmpty
                                ? Colors.amber.shade600
                                : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_selectedPjaEmployee != null)
                              _GciEmployeeAvatar(
                                photo: _selectedPjaEmployee!.foto,
                                name: _selectedPjaEmployee!.nama,
                                nik: _selectedPjaEmployee!.nik,
                                radius: 22,
                                fallbackBg: const Color(0xFFFEF3C7),
                                fallbackFg: Colors.amber.shade800,
                              )
                            else if (_pjaNamaCtrl.text.isNotEmpty)
                              _GciEmployeeAvatar(
                                photo: null,
                                name: _pjaNamaCtrl.text,
                                nik: '',
                                radius: 22,
                                fallbackBg: const Color(0xFFFEF3C7),
                                fallbackFg: Colors.amber.shade800,
                              )
                            else
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFFFFFBEB),
                                child: Icon(
                                  Icons.supervisor_account_rounded,
                                  color: Colors.amber.shade800,
                                  size: 24,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedPjaEmployee?.nama ??
                                        (_pjaNamaCtrl.text.isNotEmpty ? _pjaNamaCtrl.text : 'Pilih Supervisor Geoteknik (PJA)'),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: _selectedPjaEmployee != null || _pjaNamaCtrl.text.isNotEmpty
                                          ? const Color(0xFF92400E)
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedPjaEmployee != null
                                        ? '${_selectedPjaEmployee!.nik} • ${_selectedPjaEmployee!.jabatan} (${_selectedPjaEmployee!.perusahaan})'
                                        : (_pjaNamaCtrl.text.isNotEmpty
                                            ? 'PJA Terpilih'
                                            : 'Ketuk untuk mencari supervisor / PJA geoteknik...'),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedPjaEmployee != null || _pjaNamaCtrl.text.isNotEmpty
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedPjaEmployee != null || _pjaNamaCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                                onPressed: () {
                                  setState(() {
                                    _selectedPjaEmployee = null;
                                    _pjaNamaCtrl.clear();
                                    _pjaNikCtrl.clear();
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

                // 5. Foto Dokumentasi Kondisi Lereng
                const Row(
                  children: [
                    Icon(Icons.photo_camera_back_rounded, size: 16, color: _blueColor),
                    SizedBox(width: 8),
                    Text(
                      'Foto Dokumentasi Kondisi Lereng / Hazard Lapangan',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_fotoFile != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        Image.file(_fotoFile!, height: 190, width: double.infinity, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () => setState(() => _fotoFile = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ] else if (_existingFotoUrl != null && _existingFotoUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(_existingFotoUrl!, height: 190, width: double.infinity, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _blueColor,
                          side: const BorderSide(color: _blueColor),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Kamera', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _blueColor,
                          side: const BorderSide(color: _blueColor),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text('Galeri', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _GciEmployeePickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color themeColor;

  const _GciEmployeePickerSheet({
    required this.title,
    required this.subtitle,
    required this.themeColor,
  });

  @override
  State<_GciEmployeePickerSheet> createState() => _GciEmployeePickerSheetState();
}

class _GciEmployeePickerSheetState extends State<_GciEmployeePickerSheet> {
  final _searchCtrl = TextEditingController();
  final _db = DatabaseService();
  final _api = ApiService();

  List<_GciEmployeeItem> _allLoadedResults = [];
  List<_GciEmployeeItem> _filteredResults = [];
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
              return _GciEmployeeItem(
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
            return _GciEmployeeItem(
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
                              leading: _GciEmployeeAvatar(
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

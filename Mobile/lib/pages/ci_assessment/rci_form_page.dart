import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../widgets/top_bar.dart';
import 'rci_model.dart';

class _EmployeeOption {
  final String nik;
  final String nama;
  final String jabatan;
  final String perusahaan;
  final int? perusahaanId;
  final bool isPrimary;

  _EmployeeOption({
    required this.nik,
    required this.nama,
    required this.jabatan,
    required this.perusahaan,
    this.perusahaanId,
    this.isPrimary = false,
  });

  String get displayName => '$nama ($nik) - $jabatan';
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
  File? _fotoFile;
  String? _existingFotoUrl;

  bool _isSaving = false;
  bool _isLoadingGps = false;

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
  static const _blueAccent = Color(0xFF3B82F6);
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
      const SnackBar(content: Text('Rekomendasi otomatis disalin ke Form Perbaikan!')),
    );
  }

  // ==================== GPS Location ====================
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Layanan GPS / Lokasi tidak aktif. Silakan aktifkan GPS.');
        setState(() => _isLoadingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Izin lokasi ditolak.');
          setState(() => _isLoadingGps = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnack('Izin lokasi ditolak permanen. Buka pengaturan aplikasi.');
        setState(() => _isLoadingGps = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
        if (_lokasiCtrl.text.trim().isEmpty) {
          _lokasiCtrl.text = 'GPS: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
        }
        _isLoadingGps = false;
      });
      _showSnack('Koordinat GPS berhasil diperoleh!', isSuccess: true);
    } catch (e) {
      setState(() => _isLoadingGps = false);
      _showSnack('Gagal mengambil GPS: $e');
    }
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

  // ==================== Employee Picker Dialog ====================
  void _openEmployeeSearchModal({required bool isApprover}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        List<_EmployeeOption> results = [];
        bool isSearching = false;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            void performSearch(String q) async {
              if (q.trim().length < 2) return;
              setModalState(() => isSearching = true);
              final list = await _api.searchRciEmployees(q);
              if (modalCtx.mounted) {
                setModalState(() {
                  results = list.map((e) => _EmployeeOption(
                    nik: e['nik']?.toString() ?? '',
                    nama: e['nama']?.toString() ?? '',
                    jabatan: e['jabatan']?.toString() ?? 'Staff',
                    perusahaan: e['perusahaan']?.toString() ?? 'PT MEGA GLOBAL ENERGY',
                    perusahaanId: e['perusahaanId'] is int ? e['perusahaanId'] : null,
                  )).toList();
                  isSearching = false;
                });
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isApprover ? 'Pilih Penyetuju (Approver)' : 'Pilih Rekan Tim Sidak',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              isApprover ? 'Wajib minimal 1 orang atasan / perwakilan' : 'Rekan inspeksi bersama',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau NIK karyawan...',
                        prefixIcon: Icon(Icons.search_rounded, color: isApprover ? _emeraldColor : _blueColor),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) {
                        filter = val;
                        performSearch(val);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: isSearching
                        ? const Center(child: CircularProgressIndicator())
                        : results.isEmpty
                            ? Center(
                                child: Text(
                                  filter.length < 2 ? 'Ketik minimal 2 huruf untuk mencari...' : 'Karyawan tidak ditemukan',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              )
                            : ListView.separated(
                                itemCount: results.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final emp = results[i];
                                  final initials = emp.nama.isNotEmpty ? emp.nama[0].toUpperCase() : 'U';
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isApprover ? _emeraldColor.withValues(alpha: 0.15) : _blueColor.withValues(alpha: 0.15),
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: isApprover ? _emeraldColor : _blueColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(emp.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                    subtitle: Text('${emp.nik} • ${emp.jabatan}\n${emp.perusahaan}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isApprover ? _emeraldColor : _blueColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(modalCtx);
                                        setState(() {
                                          if (isApprover) {
                                            if (!_selectedApprovers.any((x) => x.nik == emp.nik)) {
                                              _selectedApprovers.add(emp);
                                            }
                                          } else {
                                            if (!_selectedCreators.any((x) => x.nik == emp.nik)) {
                                              _selectedCreators.add(emp);
                                            }
                                          }
                                        });
                                      },
                                      child: const Text('Pilih', style: TextStyle(fontSize: 11)),
                                    ),
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
        'lokasi': _lokasiCtrl.text.trim().isNotEmpty ? _lokasiCtrl.text.trim() : _namaJalanCtrl.text.trim(),
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

      if (_fotoFile != null) {
        final filename = _fotoFile!.path.split(Platform.pathSeparator).last;
        map['foto'] = await MultipartFile.fromFile(_fotoFile!.path, filename: filename);
      }

      final formData = FormData.fromMap(map);
      final res = await _api.saveRciReport(formData);

      setState(() => _isSaving = false);

      res.fold(
        (err) => _showSnack(err['message']?.toString() ?? 'Gagal menyimpan laporan RCI.'),
        (_) async {
          try {
            await HapticFeedback.heavyImpact();
          } catch (_) {}

          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: _emeraldColor, size: 28),
                    SizedBox(width: 10),
                    Text('Berhasil Disimpan!'),
                  ],
                ),
                content: Text(
                  widget.editItem != null
                      ? 'Laporan RCI berhasil diperbarui.'
                      : 'Laporan RCI baru berhasil disimpan dan dikirimkan ke Penyetuju.',
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
        },
      );
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
              _openEmployeeSearchModal(isApprover: true);
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
                  // Tanggal & Waktu
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _tanggal,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) setState(() => _tanggal = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Tanggal',
                              prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text(DateFormat('dd MMM yyyy').format(_tanggal), style: const TextStyle(fontSize: 13)),
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
                            decoration: InputDecoration(
                              labelText: 'Waktu',
                              prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text(_waktu.format(context), style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Area Utama Dropdown
                  DropdownButtonFormField<String>(
                    value: _masterAreas.contains(_areaCtrl.text) ? _areaCtrl.text : null,
                    decoration: InputDecoration(
                      labelText: 'Area Utama *',
                      prefixIcon: const Icon(Icons.map_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _masterAreas.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _areaCtrl.text = val);
                    },
                    validator: (v) => (_areaCtrl.text.isEmpty) ? 'Area wajib dipilih' : null,
                  ),
                  const SizedBox(height: 12),

                  // Nama Jalan & Segment
                  TextFormField(
                    controller: _namaJalanCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nama Jalan / Jalur Hauling *',
                      prefixIcon: const Icon(Icons.alt_route_rounded, size: 18),
                      hintText: 'Misal: Jalan Manado, Front Pit B',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama jalan wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

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
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _shift,
                          decoration: InputDecoration(
                            labelText: 'Shift',
                            prefixIcon: const Icon(Icons.wb_sunny_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Shift 1 (Siang)', child: Text('Shift 1 (Siang)', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Shift 2 (Malam)', child: Text('Shift 2 (Malam)', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _shift = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lokasi & GPS Button
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lokasiCtrl,
                          decoration: InputDecoration(
                            labelText: 'Lokasi Spesifik / Koordinat GPS',
                            prefixIcon: const Icon(Icons.my_location_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: _blueColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isLoadingGps
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.gps_fixed_rounded, color: Colors.white),
                        tooltip: 'Ambil GPS Aktual',
                        onPressed: _isLoadingGps ? null : _getCurrentLocation,
                      ),
                    ],
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
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: const Text('+ Tambah Rekan', style: TextStyle(fontSize: 11)),
                        onPressed: () => _openEmployeeSearchModal(isApprover: false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                        style: TextButton.styleFrom(foregroundColor: _emeraldColor, visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.shield_outlined, size: 16),
                        label: const Text('+ Tambah Penyetuju', style: TextStyle(fontSize: 11)),
                        onPressed: () => _openEmployeeSearchModal(isApprover: true),
                      ),
                    ],
                  ),
                  if (_selectedApprovers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Penyetuju belum dipilih! Format SP3 mewajibkan minimal 1 approver.',
                              style: TextStyle(color: Colors.red, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  TextFormField(
                    controller: _catatanCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Catatan Observasi Kondisi Jalan',
                      hintText: 'Tuliskan temuan atau catatan kondisi aktual di lapangan...',
                      prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _tindakanCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Rekomendasi Tindakan Perbaikan',
                      hintText: 'Misal: Perlu motor grader meratakan jalan & compactor memadatkan...',
                      prefixIcon: const Icon(Icons.handyman_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _picCtrl,
                          decoration: InputDecoration(
                            labelText: 'PIC Tindakan Perbaikan',
                            hintText: 'Misal: Road Maintenance / Grader',
                            prefixIcon: const Icon(Icons.person_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.person_search_rounded, color: Colors.white),
                        tooltip: 'Pilih PIC dari Karyawan',
                        onPressed: () {
                          // Quick picker for PIC
                          _openEmployeeSearchModal(isApprover: false);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Foto Dokumentasi
                  const Text('Foto Dokumentasi Kondisi Jalan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (_fotoFile != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_fotoFile!, height: 180, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.red,
                            radius: 16,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                              onPressed: () => setState(() => _fotoFile = null),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (_existingFotoUrl != null && _existingFotoUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _existingFotoUrl!.startsWith('http')
                            ? _existingFotoUrl!
                            : 'http://127.0.0.1:5200$_existingFotoUrl',
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Kamera'),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Galeri'),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                      ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
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

  Widget _memberCard(_EmployeeOption emp, {required bool isApprover}) {
    final initials = emp.nama.isNotEmpty ? emp.nama[0].toUpperCase() : 'U';
    final color = isApprover ? _emeraldColor : _blueColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Text(initials, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(emp.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (emp.isPrimary) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: _blueColor, borderRadius: BorderRadius.circular(4)),
                        child: const Text('Anda', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text('${emp.nik} • ${emp.jabatan} (${emp.perusahaan})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (!emp.isPrimary)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
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
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
              const Text('Defisit (meter):', style: TextStyle(fontSize: 12)),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
          const SizedBox(height: 8),

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
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _onManualScoreTapped(paramKey, score),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? _blueColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? _blueColor : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: active ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: active ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveConclusionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _scoreColor.withValues(alpha: 0.1),
            _blueAccent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _scoreColor.withValues(alpha: 0.3)),
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
                  Text('EVALUASI SEGMEN JALAN (RCI)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Target Operasional 4.00 (Draft SP3)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_actualRoadScore.toStringAsFixed(2)} / 4.00 (${_achievement.toStringAsFixed(1)}%)',
                  style: TextStyle(color: _scoreColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3-Group Table
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _grpPilarItem('Permukaan (60%)', _skorPermukaanGroup, _blueColor),
                Container(width: 1, height: 26, color: Colors.grey.shade200),
                _grpPilarItem('Berm (20%)', _skorSafetyBermGroup, _emeraldColor),
                Container(width: 1, height: 26, color: Colors.grey.shade200),
                _grpPilarItem('Drainase (20%)', _skorDrainageGroup, const Color(0xFF06B6D4)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Auto Recommendation preview
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Rekomendasi Otomatis:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _blueColor)),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                      onPressed: _applyAutoRecommendation,
                      child: const Text('Salin ke Form', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                Text(
                  _generateAutoRecommendation(),
                  style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.black87),
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
        Text(title, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(score.toStringAsFixed(2), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

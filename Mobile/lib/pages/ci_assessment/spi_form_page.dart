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
import 'spi_model.dart';

class _SpiEmployeeItem {
  final String nik;
  final String nama;
  final String departemen;
  final String jabatan;
  final String perusahaan;
  final int? perusahaanId;
  final String? foto;

  _SpiEmployeeItem({
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

class _SpiEmployeeAvatar extends StatefulWidget {
  final String? photo;
  final String name;
  final String nik;
  final double radius;
  final Color? fallbackBg;
  final Color? fallbackFg;

  const _SpiEmployeeAvatar({
    required this.photo,
    required this.name,
    required this.nik,
    this.radius = 18,
    this.fallbackBg,
    this.fallbackFg,
  });

  @override
  State<_SpiEmployeeAvatar> createState() => _SpiEmployeeAvatarState();
}

class _SpiEmployeeAvatarState extends State<_SpiEmployeeAvatar> {
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
  void didUpdateWidget(covariant _SpiEmployeeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo || oldWidget.nik != widget.nik) {
      _attempt = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.trim().isNotEmpty ? widget.name.trim()[0].toUpperCase() : 'U';
    final bg = widget.fallbackBg ?? const Color(0xFFF0FDFA);
    final fg = widget.fallbackFg ?? const Color(0xFF0D9488);

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

class SpiFormPage extends StatefulWidget {
  final SpiReportItem? editData;

  const SpiFormPage({super.key, this.editData});

  @override
  State<SpiFormPage> createState() => _SpiFormPageState();
}

class _SpiFormPageState extends State<SpiFormPage> {
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
  final _namaKolamCtrl = TextEditingController();
  final _titikPenaatanCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  String _shift = 'Shift 1 (Siang)';

  // 8 Parameters (100, 70, 40, 0)
  int _skorKapasitasEndapan = 100;
  int _skorKondisiTanggul = 100;
  int _skorSekatBaffle = 100;
  int _skorPelimpahSpillway = 100;
  int _skorFasilitasDosing = 100;
  int _skorKualitasAirFisik = 100;
  int _skorTitikPenaatanDebit = 100;
  int _skorRambuPengaman = 100;

  // Catatan, Tindakan, Foto, PIC
  final _catatanCtrl = TextEditingController();
  final _tindakanCtrl = TextEditingController();
  final _picCtrl = TextEditingController();
  _SpiEmployeeItem? _selectedPicEmployee;
  File? _fotoFile;
  String? _existingFotoUrl;

  bool _isSaving = false;

  // Master Recommendations dari Database
  List<String> _masterAreas = [];
  List<String> _masterKolams = [];
  List<String> _masterTitikPenaatans = [];
  bool _isLoadingAreas = false;

  static const _tealColor = Color(0xFF0D9488);
  static const _tealGradient = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
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
      _namaKolamCtrl.text = d.namaKolam ?? '';
      _titikPenaatanCtrl.text = d.titikPenaatan ?? '';
      _latCtrl.text = d.latitude ?? '';
      _lngCtrl.text = d.longitude ?? '';
      _shift = d.shift ?? 'Shift 1 (Siang)';

      _skorKapasitasEndapan = d.skorKapasitasEndapan;
      _skorKondisiTanggul = d.skorKondisiTanggul;
      _skorSekatBaffle = d.skorSekatBaffle;
      _skorPelimpahSpillway = d.skorPelimpahSpillway;
      _skorFasilitasDosing = d.skorFasilitasDosing;
      _skorKualitasAirFisik = d.skorKualitasAirFisik;
      _skorTitikPenaatanDebit = d.skorTitikPenaatanDebit;
      _skorRambuPengaman = d.skorRambuPengaman;

      _catatanCtrl.text = d.catatan ?? '';
      _tindakanCtrl.text = d.tindakanPerbaikan ?? '';
      _picCtrl.text = d.pic ?? '';
      _existingFotoUrl = d.fotoUrl;
    }

    _loadAreas();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _lokasiCtrl.dispose();
    _detilLokasiCtrl.dispose();
    _namaKolamCtrl.dispose();
    _titikPenaatanCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _catatanCtrl.dispose();
    _tindakanCtrl.dispose();
    _picCtrl.dispose();
    super.dispose();
  }

  // Live Score Calculation
  double get _totalScore {
    final s = (_skorKapasitasEndapan * 0.15) +
        (_skorKondisiTanggul * 0.15) +
        (_skorSekatBaffle * 0.15) +
        (_skorPelimpahSpillway * 0.15) +
        (_skorFasilitasDosing * 0.10) +
        (_skorKualitasAirFisik * 0.10) +
        (_skorTitikPenaatanDebit * 0.10) +
        (_skorRambuPengaman * 0.10);
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
        "SELECT DISTINCT nama_kolam, titik_penaatan FROM tbl_t_spi_report WHERE (nama_kolam IS NOT NULL AND nama_kolam != '') OR (titik_penaatan IS NOT NULL AND titik_penaatan != '')",
      );

      final lKolams = <String>{};
      final lTitik = <String>{};
      for (final r in localRows) {
        final k = r['nama_kolam']?.toString();
        final t = r['titik_penaatan']?.toString();
        if (k != null && k.trim().isNotEmpty) lKolams.add(k.trim());
        if (t != null && t.trim().isNotEmpty) lTitik.add(t.trim());
      }

      if (mounted) {
        setState(() {
          _masterKolams = lKolams.toList()..sort();
          _masterTitikPenaatans = lTitik.toList()..sort();
        });
      }

      final res = await _api.getSpiSuggestions();
      res.fold((l) => null, (r) {
        if (mounted) {
          final sKolams = (r['kolams'] as List?)?.map((e) => e.toString()).toList() ?? [];
          final sTitik = (r['titikPenaatans'] as List?)?.map((e) => e.toString()).toList() ?? [];

          setState(() {
            _masterKolams = {..._masterKolams, ...sKolams}.toList()..sort();
            _masterTitikPenaatans = {..._masterTitikPenaatans, ...sTitik}.toList()..sort();
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
  Future<_SpiEmployeeItem?> _openEmployeePicker({
    required String title,
    required String subtitle,
    required Color themeColor,
  }) {
    return showModalBottomSheet<_SpiEmployeeItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SpiEmployeePickerSheet(
        title: title,
        subtitle: subtitle,
        themeColor: themeColor,
      ),
    );
  }

  void _choosePic() async {
    final emp = await _openEmployeePicker(
      title: 'Pilih PIC',
      subtitle: 'Pilih penanggung jawab sediment pond',
      themeColor: _tealColor,
    );
    if (emp != null && mounted) {
      setState(() {
        _selectedPicEmployee = emp;
        _picCtrl.text = '${emp.nama} (${emp.nik})';
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
                    child: Text('Pilih Area Utama (${filtered.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                                title: Text(item, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _tealColor : Colors.black87)),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: _tealColor, size: 20) : null,
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

  void _showKolamPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _masterKolams.where((d) => d.toLowerCase().contains(filter.toLowerCase())).toList();
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
                    child: Text('Pilih Rekomendasi Kolam Sedimen (${filtered.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari nama kolam sedimen...',
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
                        ? const Center(child: Text('Tidak ada rekomendasi kolam', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (ctx, i) {
                              final item = filtered[i];
                              final isSelected = _namaKolamCtrl.text == item;
                              return ListTile(
                                title: Text(item, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _tealColor : Colors.black87)),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: _tealColor, size: 20) : null,
                                onTap: () {
                                  setState(() => _namaKolamCtrl.text = item);
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

  void _showTitikPenaatanPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _masterTitikPenaatans.where((d) => d.toLowerCase().contains(filter.toLowerCase())).toList();
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
                    child: Text('Pilih Rekomendasi Titik Penaatan (${filtered.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari titik penaatan...',
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
                        ? const Center(child: Text('Tidak ada rekomendasi titik penaatan', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (ctx, i) {
                              final item = filtered[i];
                              final isSelected = _titikPenaatanCtrl.text == item;
                              return ListTile(
                                title: Text(item, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _tealColor : Colors.black87)),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: _tealColor, size: 20) : null,
                                onTap: () {
                                  setState(() => _titikPenaatanCtrl.text = item);
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
    final userDept = profile?.depart ?? 'Environment';
    final userCompany = _selectedCompanyName ?? profile?.company ?? 'PT INDEXIM COALINDO';
    final userCompanyId = _selectedCompanyId ?? profile?.companyId ?? 0;

    final dateStr = DateFormat('yyyy-MM-dd').format(_tanggal);
    final timeStr = '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}';

    // Pastikan lokasi terisi otomatis dari GPS / nama kolam / detil
    if (_lokasiCtrl.text.trim().isEmpty) {
      if (_latCtrl.text.isNotEmpty && _lngCtrl.text.isNotEmpty) {
        _lokasiCtrl.text = 'GPS: ${_latCtrl.text}, ${_lngCtrl.text}';
      } else if (_detilLokasiCtrl.text.trim().isNotEmpty) {
        _lokasiCtrl.text = _detilLokasiCtrl.text.trim();
      } else if (_namaKolamCtrl.text.trim().isNotEmpty) {
        _lokasiCtrl.text = _namaKolamCtrl.text.trim();
      } else {
        _lokasiCtrl.text = 'Sediment Pond';
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
      'area': _areaCtrl.text.trim(),
      'lokasi': _lokasiCtrl.text.trim(),
      'detil_lokasi': _detilLokasiCtrl.text.trim(),
      'nama_kolam': _namaKolamCtrl.text.trim(),
      'titik_penaatan': _titikPenaatanCtrl.text.trim(),
      'shift': _shift,
      'latitude': _latCtrl.text.trim(),
      'longitude': _lngCtrl.text.trim(),
      'skor_kapasitas_endapan': _skorKapasitasEndapan.toString(),
      'skor_kondisi_tanggul': _skorKondisiTanggul.toString(),
      'skor_sekat_baffle': _skorSekatBaffle.toString(),
      'skor_pelimpah_spillway': _skorPelimpahSpillway.toString(),
      'skor_fasilitas_dosing': _skorFasilitasDosing.toString(),
      'skor_kualitas_air_fisik': _skorKualitasAirFisik.toString(),
      'skor_titik_penaatan_debit': _skorTitikPenaatanDebit.toString(),
      'skor_rambu_pengaman': _skorRambuPengaman.toString(),
      'catatan': _catatanCtrl.text.trim(),
      'tindakan_perbaikan': _tindakanCtrl.text.trim(),
      'pic': _picCtrl.text.trim(),
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

      final res = await _api.saveSpiReport(formData);
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
      _showSuccessDialog('Laporan SPI baru berhasil dikirim dan tersimpan di server.');
    }

    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _saveOffline(Map<String, dynamic> mapData) async {
    try {
      final sqldb = await _db.database;
      await sqldb.insert('tbl_t_spi_report', {
        'tanggal': mapData['tanggal'],
        'waktu': mapData['waktu'],
        'nik': mapData['nik'],
        'nama': mapData['nama'],
        'departemen': mapData['departemen'],
        'perusahaan': mapData['perusahaan'],
        'perusahaan_id': int.tryParse(mapData['perusahaan_id']?.toString() ?? '0'),
        'area': mapData['area'],
        'lokasi': mapData['lokasi'],
        'detil_lokasi': mapData['detil_lokasi'],
        'nama_kolam': mapData['nama_kolam'],
        'titik_penaatan': mapData['titik_penaatan'],
        'shift': mapData['shift'],
        'latitude': mapData['latitude'],
        'longitude': mapData['longitude'],
        'skor_kapasitas_endapan': int.tryParse(mapData['skor_kapasitas_endapan']?.toString() ?? '100') ?? 100,
        'skor_kondisi_tanggul': int.tryParse(mapData['skor_kondisi_tanggul']?.toString() ?? '100') ?? 100,
        'skor_sekat_baffle': int.tryParse(mapData['skor_sekat_baffle']?.toString() ?? '100') ?? 100,
        'skor_pelimpah_spillway': int.tryParse(mapData['skor_pelimpah_spillway']?.toString() ?? '100') ?? 100,
        'skor_fasilitas_dosing': int.tryParse(mapData['skor_fasilitas_dosing']?.toString() ?? '100') ?? 100,
        'skor_kualitas_air_fisik': int.tryParse(mapData['skor_kualitas_air_fisik']?.toString() ?? '100') ?? 100,
        'skor_titik_penaatan_debit': int.tryParse(mapData['skor_titik_penaatan_debit']?.toString() ?? '100') ?? 100,
        'skor_rambu_pengaman': int.tryParse(mapData['skor_rambu_pengaman']?.toString() ?? '100') ?? 100,
        'total_score': _totalScore,
        'kategori_index': _kategoriIndex,
        'catatan': mapData['catatan'],
        'tindakan_perbaikan': mapData['tindakan_perbaikan'],
        'pic': mapData['pic'],
        'foto_url': _fotoFile?.path,
        'created_at': DateTime.now().toIso8601String(),
      });

      try {
        final localId = 'spi_${DateTime.now().millisecondsSinceEpoch}';
        await OfflineSyncService.instance.enqueue(
          feature: 'spi',
          localId: localId,
          payload: {
            'map': mapData,
            if (_fotoFile != null) 'photoPath': _fotoFile!.path,
          },
        );
      } catch (_) {}

      _showSuccessDialog('Laporan SPI tersimpan secara OFFLINE. Data akan otomatis disinkronkan ke server saat jaringan tersedia.', isOffline: true);
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
                  backgroundColor: _tealColor,
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
        borderSide: const BorderSide(color: _tealColor, width: 1.5),
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
                  color: _tealColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: _tealColor),
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
                    color: _tealColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(code, style: const TextStyle(color: _tealColor, fontWeight: FontWeight.w900, fontSize: 11)),
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
                } else if (val >= 70) {
                  scoreBadgeColor = const Color(0xFF0EA5E9);
                } else if (val >= 40) {
                  scoreBadgeColor = const Color(0xFFF59E0B);
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
                      color: isSelected ? _tealColor.withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? _tealColor : const Color(0xFFE2E8F0),
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
                          color: isSelected ? _tealColor : Colors.grey.shade400,
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
        title: widget.editData != null ? 'Edit Inspeksi SPI' : 'Form Inspeksi SPI',
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
                    const Text('Total Skor SPI', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Row(
                      children: [
                        Text(
                          '$_totalScore%',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _categoryColor),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _categoryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _categoryColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            _kategoriIndex.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _categoryColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tealColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle, color: Colors.white, size: 18),
                label: Text(
                  _isSaving ? 'Menyimpan...' : (widget.editData != null ? 'Perbarui Inspeksi' : 'Simpan Inspeksi SPI'),
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
                gradient: _tealGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: _tealColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
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
                    child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sediment Pond Index (SPI)',
                          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Inspeksi & Penilaian Standar Kelayakan Kolam Pengendapan Sedimen K3L',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 1: Informasi & Lokasi Kolam Sedimen
            _buildSectionCard(
              title: '1. Identitas Kolam & Waktu Inspeksi',
              icon: Icons.pin_drop_rounded,
              children: [
                // Perusahaan
                Row(
                  children: [
                    const Icon(Icons.business_rounded, color: _tealColor, size: 16),
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

                // Area Utama
                InkWell(
                  onTap: _showAreaPicker,
                  child: IgnorePointer(
                    child: TextFormField(
                      controller: _areaCtrl,
                      decoration: _inputDecor(
                        'Area Utama *',
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

                // Nama Kolam Sedimen
                TextFormField(
                  controller: _namaKolamCtrl,
                  decoration: _inputDecor(
                    'Nama Kolam Sedimen *',
                    hint: 'Contoh: Settling Pond 01, Kolam Arboretum...',
                    icon: Icons.water_drop_rounded,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.list_alt_rounded, color: _tealColor),
                      tooltip: 'Pilih Rekomendasi Kolam',
                      onPressed: _showKolamPicker,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama kolam wajib diisi' : null,
                ),
                if (_masterKolams.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _masterKolams.take(6).map((kolam) {
                        final isSelected = _namaKolamCtrl.text.trim().toLowerCase() == kolam.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            label: Text(kolam,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : _tealColor)),
                            backgroundColor: isSelected ? _tealColor : _tealColor.withOpacity(0.08),
                            side: BorderSide(color: isSelected ? _tealColor : _tealColor.withOpacity(0.2)),
                            onPressed: () => setState(() => _namaKolamCtrl.text = kolam),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Titik Penaatan Lingkungan
                TextFormField(
                  controller: _titikPenaatanCtrl,
                  decoration: _inputDecor(
                    'Titik Penaatan Lingkungan',
                    hint: 'Contoh: Point Compliance A, Outfall SP-01...',
                    icon: Icons.location_searching_rounded,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.list_alt_rounded, color: _tealColor),
                      tooltip: 'Pilih Rekomendasi Titik Penaatan',
                      onPressed: _showTitikPenaatanPicker,
                    ),
                  ),
                ),
                if (_masterTitikPenaatans.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _masterTitikPenaatans.take(6).map((t) {
                        final isSelected = _titikPenaatanCtrl.text.trim().toLowerCase() == t.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            label: Text(t,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : _tealColor)),
                            backgroundColor: isSelected ? _tealColor : _tealColor.withOpacity(0.08),
                            side: BorderSide(color: isSelected ? _tealColor : _tealColor.withOpacity(0.2)),
                            onPressed: () => setState(() => _titikPenaatanCtrl.text = t),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Keterangan Tambahan / Detil Akses Lokasi
                TextFormField(
                  controller: _detilLokasiCtrl,
                  decoration: _inputDecor(
                    'Detil Akses / Keterangan Lokasi (Opsional)',
                    hint: 'Contoh: Sebelah barat Workshop, KM 12 Jalur Outfall...',
                    icon: Icons.tag_rounded,
                  ),
                ),
                const SizedBox(height: 12),

                // Koordinat Lokasi Kolam (GPS Akurat)
                SapGpsLocationCard(
                  latController: _latCtrl,
                  lngController: _lngCtrl,
                  lokasiController: _lokasiCtrl,
                  primaryColor: _tealColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 2: 8 Parameter Teknis Sediment Pond
            _buildSectionCard(
              title: '2. Penilaian 8 Parameter Sediment Pond',
              icon: Icons.checklist_rounded,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Skor: $_totalScore%',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _categoryColor),
                ),
              ),
              children: [
                _buildParamCard(
                  code: 'P01',
                  title: 'Kapasitas Endapan Sedimen',
                  weight: '15%',
                  currentValue: _skorKapasitasEndapan,
                  onChanged: (v) => setState(() => _skorKapasitasEndapan = v),
                  options: const [
                    {'val': 100, 'desc': '< 50% Kapasitas (Luas & Dalam, daya tampung aman)'},
                    {'val': 70, 'desc': '50% - 70% Kapasitas (Sedimen mulai naik, rencanakan desilting)'},
                    {'val': 40, 'desc': '70% - 85% Kapasitas (Kritis, segera jadwalkan pengerukan)'},
                    {'val': 0, 'desc': '> 85% Over Capacity / Dangkal ekstrem (Stop aliran)'},
                  ],
                ),
                _buildParamCard(
                  code: 'P02',
                  title: 'Tanggul & Kestabilan Dike Embankment',
                  weight: '15%',
                  currentValue: _skorKondisiTanggul,
                  onChanged: (v) => setState(() => _skorKondisiTanggul = v),
                  options: const [
                    {'val': 100, 'desc': 'Tanggul kokoh sempurna, tidak ada retakan atau rembesan'},
                    {'val': 70, 'desc': 'Erosi permukaan minor, freeboard aman terjaga'},
                    {'val': 40, 'desc': 'Rembesan/retakan minor pada lereng/badan tanggul'},
                    {'val': 0, 'desc': 'Ambles/retak mayor/potensi tanggul jebol tinggi'},
                  ],
                ),
                _buildParamCard(
                  code: 'P03',
                  title: 'Sekat Baffle & Kompartemen Retensi',
                  weight: '15%',
                  currentValue: _skorSekatBaffle,
                  onChanged: (v) => setState(() => _skorSekatBaffle = v),
                  options: const [
                    {'val': 100, 'desc': 'Sekat lengkap, aliran zig-zag pengendapan maksimal'},
                    {'val': 70, 'desc': 'Sekat utuh, endapan mulai mengurangi kecepatan retensi'},
                    {'val': 40, 'desc': 'Sekat bocor / aliran langsung (short-circuiting)'},
                    {'val': 0, 'desc': 'Sekat roboh / rusak total / tidak berfungsi'},
                  ],
                ),
                _buildParamCard(
                  code: 'P04',
                  title: 'Saluran Pelimpah & Spillway Structure',
                  weight: '15%',
                  currentValue: _skorPelimpahSpillway,
                  onChanged: (v) => setState(() => _skorPelimpahSpillway = v),
                  options: const [
                    {'val': 100, 'desc': 'Spillway bersih lancar, tidak ada hambatan aliran'},
                    {'val': 70, 'desc': 'Sampah/ranting/sedimen ringan di mulut spillway'},
                    {'val': 40, 'desc': 'Tersumbat sebagian / erosi riprap penahan spillway'},
                    {'val': 0, 'desc': 'Tersumbat total / struktur spillway hancur jebol'},
                  ],
                ),
                _buildParamCard(
                  code: 'P05',
                  title: 'Fasilitas Dosing & Koagulan / Flokulan',
                  weight: '10%',
                  currentValue: _skorFasilitasDosing,
                  onChanged: (v) => setState(() => _skorFasilitasDosing = v),
                  options: const [
                    {'val': 100, 'desc': 'Dosing otomatis/manual optimal, stok tawas/PAC siap'},
                    {'val': 70, 'desc': 'Dosing berjalan normal, stok koagulan terbatas'},
                    {'val': 40, 'desc': 'Dosing terhambat / pengadukan tidak merata'},
                    {'val': 0, 'desc': 'Tanpa dosing / pompa dosing & sistem rusak total'},
                  ],
                ),
                _buildParamCard(
                  code: 'P06',
                  title: 'Kualitas Air Fisik & TSS Visual',
                  weight: '10%',
                  currentValue: _skorKualitasAirFisik,
                  onChanged: (v) => setState(() => _skorKualitasAirFisik = v),
                  options: const [
                    {'val': 100, 'desc': 'Air jernih di titik outfall, TSS visual rendah'},
                    {'val': 70, 'desc': 'Air agak keruh, masih memenuhi baku mutu lingkungan'},
                    {'val': 40, 'desc': 'Air keruh kecoklatan / ada indikasi minyak terbawa'},
                    {'val': 0, 'desc': 'Sangat keruh pekat / baku mutu lingkungan terlampaui'},
                  ],
                ),
                _buildParamCard(
                  code: 'P07',
                  title: 'Titik Pantau & Alat Ukur Debit',
                  weight: '10%',
                  currentValue: _skorTitikPenaatanDebit,
                  onChanged: (v) => setState(() => _skorTitikPenaatanDebit = v),
                  options: const [
                    {'val': 100, 'desc': 'V-Notch/Cipoletti/Flowmeter akurat & terbaca jelas'},
                    {'val': 70, 'desc': 'Alat ukur debit terbaca, kalibrasi perlu diperbarui'},
                    {'val': 40, 'desc': 'Alat ukur tertutup lumpur / skala pudar / rusak ringan'},
                    {'val': 0, 'desc': 'Tanpa alat ukur debit / struktur hancur total'},
                  ],
                ),
                _buildParamCard(
                  code: 'P08',
                  title: 'Rambu Keselamatan & Pengaman',
                  weight: '10%',
                  currentValue: _skorRambuPengaman,
                  onChanged: (v) => setState(() => _skorRambuPengaman = v),
                  options: const [
                    {'val': 100, 'desc': 'Rambu bahaya tenggelam, lifebuoy & tali pengaman lengkap'},
                    {'val': 70, 'desc': 'Rambu terpasang, pelampung / pengaman perlu perapihan'},
                    {'val': 40, 'desc': 'Rambu pudar / alat keselamatan darurat tidak lengkap'},
                    {'val': 0, 'desc': 'Tanpa rambu K3L & tanpa pengaman keselamatan sama sekali'},
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 3: Catatan, Tindakan, PIC & Foto Dokumentasi
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
                          Icon(Icons.notes_rounded, size: 16, color: _tealColor),
                          SizedBox(width: 8),
                          Text(
                            'Catatan Observasi Kondisi Sediment Pond',
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
                          hintText: 'Tuliskan observasi kondisi aktual tanggul, sedimen, saluran pelimpah...',
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
                          Icon(Icons.handyman_rounded, size: 16, color: _tealColor),
                          SizedBox(width: 8),
                          Text(
                            'Rencana Tindakan Perbaikan (Corrective Action)',
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
                          hintText: 'Contoh: Desilting sedimen, penambahan koagulan, pembersihan spillway...',
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
                        Icon(Icons.person_pin_circle_rounded, size: 16, color: _tealColor),
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
                              ? const Color(0xFFF0FDFA)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedPicEmployee != null || _picCtrl.text.isNotEmpty
                                ? _tealColor
                                : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_selectedPicEmployee != null)
                              _SpiEmployeeAvatar(
                                photo: _selectedPicEmployee!.foto,
                                name: _selectedPicEmployee!.nama,
                                nik: _selectedPicEmployee!.nik,
                                radius: 22,
                                fallbackBg: const Color(0xFFCCFBF1),
                                fallbackFg: _tealColor,
                              )
                            else if (_picCtrl.text.isNotEmpty)
                              _SpiEmployeeAvatar(
                                photo: null,
                                name: _picCtrl.text,
                                nik: '',
                                radius: 22,
                                fallbackBg: const Color(0xFFCCFBF1),
                                fallbackFg: _tealColor,
                              )
                            else
                              const CircleAvatar(
                                radius: 22,
                                backgroundColor: Color(0xFFF0FDFA),
                                child: Icon(
                                  Icons.person_search_rounded,
                                  color: _tealColor,
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
                                          ? const Color(0xFF0F766E)
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
                                          ? const Color(0xFF0D9488)
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

                // 4. Foto Dokumentasi Kondisi Sediment Pond
                const Row(
                  children: [
                    Icon(Icons.photo_camera_back_rounded, size: 16, color: _tealColor),
                    SizedBox(width: 8),
                    Text(
                      'Foto Dokumentasi Kondisi Sediment Pond',
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
                          foregroundColor: _tealColor,
                          side: const BorderSide(color: _tealColor),
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
                          foregroundColor: _tealColor,
                          side: const BorderSide(color: _tealColor),
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

class _SpiEmployeePickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color themeColor;

  const _SpiEmployeePickerSheet({
    required this.title,
    required this.subtitle,
    required this.themeColor,
  });

  @override
  State<_SpiEmployeePickerSheet> createState() => _SpiEmployeePickerSheetState();
}

class _SpiEmployeePickerSheetState extends State<_SpiEmployeePickerSheet> {
  final _searchCtrl = TextEditingController();
  final _db = DatabaseService();
  final _api = ApiService();

  List<_SpiEmployeeItem> _allLoadedResults = [];
  List<_SpiEmployeeItem> _filteredResults = [];
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
              return _SpiEmployeeItem(
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
            return _SpiEmployeeItem(
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
                              leading: _SpiEmployeeAvatar(
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

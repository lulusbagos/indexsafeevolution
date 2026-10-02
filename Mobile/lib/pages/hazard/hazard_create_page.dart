import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/hazard_hub_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';

class HazardCreatePage extends StatefulWidget {
  final HazardReportItem? editItem; // Jika mode edit temuan yang masih open

  const HazardCreatePage({this.editItem, super.key});

  @override
  State<HazardCreatePage> createState() => _HazardCreatePageState();
}

class _HazardCreatePageState extends State<HazardCreatePage> {
  final _api = ApiService();
  final _db = DatabaseService();
  final _picker = ImagePicker();

  DateTime _tanggal = DateTime.now();
  TimeOfDay _waktu = TimeOfDay.now();

  String _area = '';
  String _lokasi = '';
  String _detilLokasi = '';
  String _kategoriBahaya = 'Kondisi Tidak Aman';
  String _jenisBahaya = 'Biologi';
  String _jenisKetidaksesuaian = '';
  String _tingkatResiko = 'Sedang';
  String _temuan = '';
  String _perbaikan = '';
  String _tindakanPerbaikan = '';

  PjaSearchResult? _selectedPja;
  File? _fotoTemuan;
  File? _fotoPerbaikan;
  bool _isSelfClosed = false;
  bool _isSubmitting = false;

  final TextEditingController _lokasiCtrl = TextEditingController();
  final TextEditingController _detilLokasiCtrl = TextEditingController();
  final TextEditingController _ketidaksesuaianCtrl = TextEditingController();
  final TextEditingController _temuanCtrl = TextEditingController();
  final TextEditingController _perbaikanCtrl = TextEditingController();
  final TextEditingController _tindakanCtrl = TextEditingController();
  final TextEditingController _pjaSearchCtrl = TextEditingController();

  List<String> _masterAreas = [
    'PIT AREA',
    'DISPOSAL',
    'HAUL ROAD',
    'WORKSHOP',
    'PORT / JETTY',
    'OFFICE AREA',
    'MESS / CAMP',
    'WAREHOUSE',
    'EXPLORATION',
    'WATER TREATMENT PLANT'
  ];

  final List<String> _jenisBahayaList = [
    'Biologi',
    'Dan lain-lain',
    'Ergonomi',
    'Fasilitas Emergency',
    'Fisikal',
    'Kelistrikan',
    'Kimia',
    'Lingkungan',
    'Longsor',
    'Mekanikal',
    'Perilaku',
    'Traffic'
  ];

  List<PjaSearchResult> _pjaSearchResults = [];
  bool _isSearchingPja = false;

  @override
  void initState() {
    super.initState();
    _loadAreasFromMaster();

    if (widget.editItem != null) {
      final e = widget.editItem!;
      try {
        _tanggal = DateTime.parse(e.tanggal);
      } catch (_) {}
      _area = e.area ?? '';
      _lokasi = e.lokasi ?? '';
      _lokasiCtrl.text = _lokasi;
      _detilLokasi = e.detilLokasi ?? '';
      _detilLokasiCtrl.text = _detilLokasi;
      _kategoriBahaya = e.kategoriBahaya ?? 'Kondisi Tidak Aman';
      _jenisBahaya = e.jenisBahaya ?? 'Biologi';
      _jenisKetidaksesuaian = e.jenisKetidaksesuaian ?? '';
      _ketidaksesuaianCtrl.text = _jenisKetidaksesuaian;
      _tingkatResiko = e.tingkatResiko;
      _temuan = e.temuan;
      _temuanCtrl.text = _temuan;
      _perbaikan = e.perbaikan ?? '';
      _perbaikanCtrl.text = _perbaikan;
      _tindakanPerbaikan = e.tindakanPerbaikan ?? '';
      _tindakanCtrl.text = _tindakanPerbaikan;

      if (e.pja != null && e.pja!.isNotEmpty) {
        _selectedPja = PjaSearchResult(
          nik: e.nikPja ?? '',
          nama: e.pja!,
          jabatan: 'PJA Terpilih',
          departemen: e.departemenPja ?? 'GENERAL',
          perusahaan: 'PT INDEXIM COALINDO',
        );
      }
    } else {
      _fetchCurrentGps(silent: true);
    }
  }

  @override
  void dispose() {
    _lokasiCtrl.dispose();
    _detilLokasiCtrl.dispose();
    _ketidaksesuaianCtrl.dispose();
    _temuanCtrl.dispose();
    _perbaikanCtrl.dispose();
    _tindakanCtrl.dispose();
    _pjaSearchCtrl.dispose();
    super.dispose();
  }

  void _loadAreasFromMaster() async {
    try {
      final list = await _db.rawQuery("SELECT name FROM enum_masters WHERE type='area' AND deleted_at IS NULL ORDER BY name");
      if (list.isNotEmpty) {
        setState(() {
          _masterAreas = list.map((e) => e['name'].toString()).toList();
          if (_area.isEmpty && _masterAreas.isNotEmpty) {
            _area = _masterAreas.first;
          }
        });
      } else if (_area.isEmpty && _masterAreas.isNotEmpty) {
        _area = _masterAreas.first;
      }
    } catch (_) {
      if (_area.isEmpty && _masterAreas.isNotEmpty) {
        _area = _masterAreas.first;
      }
    }
  }

  void _fetchCurrentGps({bool silent = false}) {
    fillGpsCoordinate(
      context,
      _lokasiCtrl,
      () {
        setState(() {
          _lokasi = _lokasiCtrl.text;
          _detilLokasi = _detilLokasiCtrl.text;
        });
        if (!silent && mounted) {
          SnackBarMsg.success(context, 'Koordinat GPS berhasil diperoleh!');
        }
      },
      silent: silent,
    );
  }

  void _searchPjaOnline(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _pjaSearchResults = []);
      return;
    }
    setState(() => _isSearchingPja = true);
    final res = await _api.searchPja(query);
    if (!mounted) return;
    res.fold(
      (err) => setState(() => _isSearchingPja = false),
      (data) {
        setState(() {
          _isSearchingPja = false;
          _pjaSearchResults = data.map((e) => PjaSearchResult.fromJson(e)).toList();
        });
      },
    );
  }

  Future<void> _pickImage(bool isBefore) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFEA580C)),
              title: const Text('Buka Kamera', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFEA580C)),
              title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() {
          if (isBefore) {
            _fotoTemuan = File(picked.path);
          } else {
            _fotoPerbaikan = File(picked.path);
          }
        });
      }
    }
  }

  void _submitHazard() async {
    if (_temuanCtrl.text.trim().isEmpty) {
      SnackBarMsg.danger(context, 'Detail temuan hazard wajib diisi.');
      return;
    }
    if (_lokasiCtrl.text.trim().isEmpty) {
      SnackBarMsg.danger(context, 'Lokasi spesifik wajib diisi.');
      return;
    }
    if (!_isSelfClosed && _selectedPja == null) {
      SnackBarMsg.danger(context, 'Penanggung Jawab Area (PJA) wajib dipilih dari hasil pencarian.');
      return;
    }
    if (_fotoTemuan == null && widget.editItem == null) {
      SnackBarMsg.danger(context, 'Foto bukti temuan wajib diunggah.');
      return;
    }

    setState(() => _isSubmitting = true);

    final fields = <String, dynamic>{
      'tanggal': DateFormat('yyyy-MM-dd').format(_tanggal),
      'waktu': '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}',
      'area': _area.isNotEmpty ? _area : 'PIT AREA',
      'lokasi': _lokasiCtrl.text.trim(),
      'detil_lokasi': _detilLokasiCtrl.text.trim(),
      'kategori_bahaya': _kategoriBahaya,
      'jenis_bahaya': _jenisBahaya,
      'jenis_ketidaksesuaian': _ketidaksesuaianCtrl.text.trim(),
      'tingkat_resiko': _tingkatResiko,
      'temuan': _temuanCtrl.text.trim(),
      'perbaikan': _perbaikanCtrl.text.trim(),
      'tindakan_perbaikan': _tindakanCtrl.text.trim(),
      'pja': _selectedPja?.nama ?? '',
      'nik_pja': _selectedPja?.nik ?? '',
      'departemen_pja': _selectedPja?.departemen ?? '',
      'status_temuan': _isSelfClosed ? 'Closed' : 'Open',
    };

    final result = await _api.createHazardReport(
      fields,
      fotoTemuan: _fotoTemuan,
      fotoPerbaikan: _fotoPerbaikan,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (err) {
        final msg = err['message']?.toString() ?? 'Gagal menyimpan laporan hazard.';
        SnackBarMsg.danger(context, msg);
      },
      (data) {
        SnackBarMsg.success(context, 'Laporan Hazard berhasil dikirim ke server!');
        Navigator.pop(context, true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: TopBar(
        title: widget.editItem != null ? 'Edit Temuan Hazard' : 'Temuan Hazard',
      ),
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF64748B).withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Formulir Laporan Hazard',
                            style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Laporkan kondisi & tindakan berbahaya untuk keselamatan bersama.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Form Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF64748B).withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waktu & Tanggal
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePicker(
                            label: 'Tanggal Temuan',
                            date: _tanggal,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _tanggal,
                                firstDate: DateTime(2023),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => _tanggal = picked);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimePicker(
                            label: 'Waktu Temuan',
                            time: _waktu,
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _waktu,
                              );
                              if (picked != null) setState(() => _waktu = picked);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Area Utama
                    const Text('Area Utama', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _masterAreas.contains(_area) ? _area : (_masterAreas.isNotEmpty ? _masterAreas.first : null),
                          dropdownColor: Colors.white,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                          items: _masterAreas.map((a) {
                            return DropdownMenuItem<String>(
                              value: a,
                              child: Text(a, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _area = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Lokasi Spesifik + Tombol GPS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lokasi Spesifik / Koordinat *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                        InkWell(
                          onTap: () => _fetchCurrentGps(silent: false),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: const [
                                Icon(Icons.my_location_rounded, color: Color(0xFF0284C7), size: 14),
                                SizedBox(width: 4),
                                Text('Ambil GPS', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _lokasiCtrl,
                      hint: 'Contoh: KM 12 Front Loading Pit 3',
                      icon: Icons.place_rounded,
                    ),

                    const SizedBox(height: 14),

                    // Detail Lokasi
                    const Text('Detail Lokasi / Benchmark', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _detilLokasiCtrl,
                      hint: 'Patokan atau keterangan titik koordinat...',
                      icon: Icons.near_me_rounded,
                    ),

                    const SizedBox(height: 14),

                    // Kategori Bahaya & Jenis Bahaya
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kategori Bahaya', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _kategoriBahaya,
                                    dropdownColor: Colors.white,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'Kondisi Tidak Aman', child: Text('Kondisi Tidak Aman', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12))),
                                      DropdownMenuItem(value: 'Tindakan Tidak Aman', child: Text('Tindakan Tidak Aman', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12))),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) setState(() => _kategoriBahaya = v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Jenis Bahaya', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _jenisBahayaList.contains(_jenisBahaya) ? _jenisBahaya : _jenisBahayaList.first,
                                    dropdownColor: Colors.white,
                                    isExpanded: true,
                                    items: _jenisBahayaList.map((j) {
                                      return DropdownMenuItem(value: j, child: Text(j, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12)));
                                    }).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _jenisBahaya = v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Jenis Ketidaksesuaian
                    const Text('Jenis Ketidaksesuaian', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _ketidaksesuaianCtrl,
                      hint: 'Misal: Tidak Pakai APD, Rambu Patah, Ceceran Oli',
                      icon: Icons.rule_folder_rounded,
                    ),

                    const SizedBox(height: 14),

                    // Tingkat Risiko (Selector Buttons)
                    const Text('Tingkat Risiko *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRiskChip('Rendah', const Color(0xFF059669), const Color(0xFFECFDF5)),
                        const SizedBox(width: 6),
                        _buildRiskChip('Sedang', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
                        const SizedBox(width: 6),
                        _buildRiskChip('Tinggi', const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
                        const SizedBox(width: 6),
                        _buildRiskChip('Ekstrim', const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Detil Temuan Hazard
                    const Text('Detil Temuan Hazard *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _buildTextArea(
                      controller: _temuanCtrl,
                      hint: 'Jelaskan kondisi atau tindakan bahaya sedetail mungkin...',
                      rows: 3,
                    ),

                    const SizedBox(height: 14),

                    // Tindakan Perbaikan Langsung
                    const Text('Tindakan Perbaikan Langsung (Bila Ada)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _buildTextArea(
                      controller: _perbaikanCtrl,
                      hint: 'Tindakan koreksi instan yang sudah langsung dilakukan...',
                      rows: 2,
                    ),

                    const SizedBox(height: 14),

                    // Rencana Tindakan Lanjutan
                    const Text('Rencana Tindakan Lanjutan', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _buildTextArea(
                      controller: _tindakanCtrl,
                      hint: 'Rekomendasi rencana perbaikan permanen...',
                      rows: 2,
                    ),

                    const SizedBox(height: 16),

                    // Penanggung Jawab Area (PJA)
                    Container(
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
                            children: const [
                              Icon(Icons.person_pin_rounded, color: Color(0xFF0284C7), size: 18),
                              SizedBox(width: 8),
                              Text('Penanggung Jawab Area (PJA) *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_selectedPja == null) ...[
                            _buildTextField(
                              controller: _pjaSearchCtrl,
                              hint: 'Cari NIK atau Nama PJA...',
                              icon: Icons.search_rounded,
                              onChanged: _searchPjaOnline,
                            ),
                            if (_isSearchingPja)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEA580C)))),
                              ),
                            if (_pjaSearchResults.isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(maxHeight: 180),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _pjaSearchResults.length,
                                  separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                                  itemBuilder: (ctx, idx) {
                                    final p = _pjaSearchResults[idx];
                                    return ListTile(
                                      dense: true,
                                      title: Text(p.nama, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                                      subtitle: Text('${p.nik} • ${p.departemen} • ${p.perusahaan}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                                      onTap: () {
                                        setState(() {
                                          _selectedPja = p;
                                          _pjaSearchResults.clear();
                                          _pjaSearchCtrl.clear();
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF16A34A),
                                    child: Text(
                                      _selectedPja!.nama.isNotEmpty ? _selectedPja!.nama[0].toUpperCase() : 'P',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_selectedPja!.nama, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text('${_selectedPja!.nik} • ${_selectedPja!.departemen}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                                        Text(_selectedPja!.perusahaan, style: const TextStyle(color: Color(0xFF0284C7), fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 18),
                                    onPressed: () => setState(() => _selectedPja = null),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Upload Foto Temuan (Before)
                    const Text('Foto Bukti Temuan (Before) *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _buildPhotoPicker(
                      file: _fotoTemuan,
                      existingUrl: widget.editItem?.fotoTemuan,
                      label: 'Ambil / Pilih Foto Temuan',
                      onTap: () => _pickImage(true),
                      onRemove: () => setState(() => _fotoTemuan = null),
                    ),

                    const SizedBox(height: 16),

                    // Switch Langsung Selesai / Self Closed
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isSelfClosed ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isSelfClosed ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tindakan Sudah Selesai Langsung?',
                                style: TextStyle(
                                  color: _isSelfClosed ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Status akan langsung menjadi CLOSED.', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                            ],
                          ),
                          Switch(
                            value: _isSelfClosed,
                            activeColor: const Color(0xFF059669),
                            onChanged: (v) => setState(() => _isSelfClosed = v),
                          ),
                        ],
                      ),
                    ),

                    // Foto Perbaikan (After) jika status langsung closed
                    if (_isSelfClosed) ...[
                      const SizedBox(height: 14),
                      const Text('Foto Bukti Perbaikan (After)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _buildPhotoPicker(
                        file: _fotoPerbaikan,
                        existingUrl: widget.editItem?.fotoPerbaikan,
                        label: 'Ambil / Pilih Foto Bukti Perbaikan',
                        onTap: () => _pickImage(false),
                        onRemove: () => setState(() => _fotoPerbaikan = null),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _submitHazard,
                        icon: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          _isSubmitting ? 'MENYIMPAN LAPORAN...' : 'KIRIM LAPORAN HAZARD',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker({required String label, required DateTime date, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Color(0xFFEA580C), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(date),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker({required String label, required TimeOfDay time, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_filled_rounded, color: Color(0xFFEA580C), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String hint,
    int rows = 3,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: controller,
        maxLines: rows,
        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildRiskChip(String label, Color color, Color bg) {
    final selected = _tingkatResiko.toLowerCase() == label.toLowerCase();
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tingkatResiko = label),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: selected ? 1.5 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker({
    File? file,
    String? existingUrl,
    required String label,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    if (file != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    if (existingUrl != null && existingUrl.isNotEmpty) {
      final fullUrl = existingUrl.startsWith('http') ? existingUrl : '${ApiService().baseUrl}$existingUrl';
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              fullUrl,
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.camera_alt_rounded, size: 14),
              label: const Text('Ganti Foto', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_rounded, color: Color(0xFFEA580C), size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

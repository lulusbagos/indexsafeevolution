import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/helpers.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';

class SafetyTalkFormPage extends StatefulWidget {
  const SafetyTalkFormPage({this.existingId, super.key});

  final int? existingId;

  @override
  State<SafetyTalkFormPage> createState() => _SafetyTalkFormPageState();
}

class _SafetyTalkFormPageState extends State<SafetyTalkFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  final _locationDetail = TextEditingController();
  final _title = TextEditingController();
  final _remark = TextEditingController();
  final List<MapEntry<int, dynamic>> _areaList = [];
  List<MapEntry<int, dynamic>> _locationList = [];
  DateTime? _date = DateTime.now();
  String? _time = DateFormat('HH:mm').format(DateTime.now());
  int? _areaId;
  int? _locationId;
  String? _selfImage;
  String? _eventImage;
  bool _isSaving = false;
  bool _loadingMaster = true;
  Map<String, dynamic>? _existing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillGpsFromDevice(silent: true);
      _loadMbsForm();
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  Future<void> _fillGpsFromDevice({bool silent = false}) {
    return fillGpsCoordinate(
      context,
      _locationDetail,
      () => setState(() {}),
      silent: silent,
    );
  }

  Future<void> _addCustomLocation() async {
    final item = await showAddCustomLocationDialog(
      context: context,
      db: _db,
      areaId: _areaId,
    );
    if (item == null) return;
    setState(() {
      _locationList.add(item);
      _locationList.sort((a, b) => a.value.compareTo(b.value));
      _locationId = item.key;
    });
  }

  Future<void> _loadMbsForm() async {
    final master = await _api.getSafetyTalkData();
    if (!mounted) return;
    if (master != null) {
      _areaList
        ..clear()
        ..addAll((master['areas'] as List).map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return MapEntry(item['id'] as int, item['name']);
        }));
    } else {
      try {
        final sqldb = await _db.database;
        final rows = await sqldb.rawQuery(
          "SELECT DISTINCT area_utama FROM tbl_m_benchmark WHERE area_utama IS NOT NULL AND area_utama != '' ORDER BY area_utama",
        );
        if (rows.isNotEmpty) {
          _areaList
            ..clear()
            ..addAll(List.generate(rows.length, (i) => MapEntry(i + 1, rows[i]['area_utama'].toString())));
        } else {
          final locRows = await sqldb.rawQuery(
            "SELECT DISTINCT area FROM locations WHERE area IS NOT NULL AND area != '' ORDER BY area",
          );
          if (locRows.isNotEmpty) {
            _areaList
              ..clear()
              ..addAll(List.generate(locRows.length, (i) => MapEntry(i + 1, locRows[i]['area'].toString())));
          }
        }
      } catch (_) {}
    }
    if (widget.existingId != null) {
      _existing = await _api.getSafetyTalk(widget.existingId!);
      final data = _existing;
      if (data != null) {
        _title.text = data['judul']?.toString() ?? '';
        _remark.text = data['keterangan']?.toString() ?? '';
        _locationDetail.text = data['lokasi']?.toString() ?? '';
        final date = DateTime.tryParse(data['tanggal']?.toString() ?? '');
        if (date != null) _date = date;
        _time = data['waktu']?.toString().substring(0, 5);
        final area = data['area']?.toString();
        final match = _areaList.where((e) => e.value.toString() == area);
        if (match.isNotEmpty) {
          _areaId = match.first.key;
          await _getLocation(_areaId!, selected: data['detilLokasi']?.toString());
        }
      }
    }
    if (mounted) setState(() => _loadingMaster = false);
  }

  Future<void> _getLocation(int val, {String? selected}) async {
    _areaId = val;
    _locationId = null;
    final areaMatch = _areaList.where((e) => e.key == val);
    if (areaMatch.isEmpty) return;
    final area = areaMatch.first.value.toString();
    var locations = await _api.getSafetyTalkBenchmarks(area);
    if (locations.isEmpty) {
      try {
        final sqldb = await _db.database;
        final bmRows = await sqldb.rawQuery(
          "SELECT DISTINCT nama_benchmark FROM tbl_m_benchmark WHERE area_utama = ? AND nama_benchmark IS NOT NULL AND nama_benchmark != '' ORDER BY nama_benchmark",
          [area],
        );
        locations = bmRows.map((r) => r['nama_benchmark'].toString()).toList();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _locationList = List.generate(locations.length, (i) => MapEntry(i + 1, locations[i]));
      if (selected != null) {
        final current = _locationList.where((e) => e.value.toString() == selected);
        if (current.isNotEmpty) _locationId = current.first.key;
      }
    });
  }

  Future<void> _pickPhoto({required bool isSelf}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0284C7)),
                title: const Text('Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF16A34A)),
                title: const Text('Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final file = await pickImage(source: source);
    if (file != null && mounted) {
      setState(() {
        if (isSelf) {
          _selfImage = file.path;
        } else {
          _eventImage = file.path;
        }
      });
    }
  }

  Widget _buildPhotoBox({
    required String label,
    required String? localPath,
    required String? remoteUrl,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasImage = (localPath != null && localPath.isNotEmpty) || (remoteUrl != null && remoteUrl.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      if (localPath != null && localPath.isNotEmpty)
                        Image.file(File(localPath), fit: BoxFit.cover)
                      else if (remoteUrl != null && remoteUrl.isNotEmpty)
                        Image.network('${_api.mbsWebUrl}$remoteUrl', fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: InkWell(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded, size: 34, color: Color(0xFF94A3B8)),
                      SizedBox(height: 8),
                      Text(
                        'Ambil Foto / Dari Galeri',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const TopBar(title: 'Safety Talk', back: 2),
        body: _loadingMaster
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SapHeaderCard(
                      title: 'Formulir Safety Talk',
                      subtitle: 'Sosialisasi dan komunikasi keselamatan bersama tim kerja.',
                      icon: Icons.record_voice_over_rounded,
                      accentColor: Color(0xFF7C4DE8),
                      badgeBgColor: Color(0xFFF5F3FF),
                      badgeBorderColor: Color(0xFFEDE9FE),
                    ),

                    // SECTION 1: Waktu & Lokasi
                    SapSectionCard(
                      stepNumber: '1',
                      title: 'WAKTU & LOKASI KEGIATAN',
                      subtitle: 'Tanggal, jam dan titik lokasi safety talk dilakukan',
                      icon: Icons.location_on_rounded,
                      accentColor: const Color(0xFF0284C7),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SapDatePickerTile(
                                label: 'Tanggal',
                                date: _date ?? DateTime.now(),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _date ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) setState(() => _date = picked);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SapTimePickerTile(
                                label: 'Jam',
                                timeText: _time ?? DateFormat('HH:mm').format(DateTime.now()),
                                onTap: () async {
                                  final now = TimeOfDay.now();
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: now,
                                  );
                                  if (picked != null) {
                                    final hh = picked.hour.toString().padLeft(2, '0');
                                    final mm = picked.minute.toString().padLeft(2, '0');
                                    setState(() => _time = '$hh:$mm');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        const Text('AREA UTAMA *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _areaId,
                              isExpanded: true,
                              hint: const Text('Pilih Area Utama', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                              items: _areaList.map((item) {
                                return DropdownMenuItem<int>(
                                  value: item.key,
                                  child: Text(
                                    item.value.toString(),
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (int? val) {
                                if (val != null) {
                                  setState(() => _getLocation(val));
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        const Text('LOKASI / BENCHMARK *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _locationId,
                              isExpanded: true,
                              hint: const Text('Pilih Detail Lokasi', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                              items: _locationList.map((item) {
                                return DropdownMenuItem<int>(
                                  value: item.key,
                                  child: Text(
                                    item.value.toString(),
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (int? val) {
                                if (val != null) setState(() => _locationId = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AddCustomLocationButton(onPressed: _addCustomLocation),
                        const SizedBox(height: 12),

                        const Text('DETAIL LOKASI / GPS KOORDINAT', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _locationDetail,
                          decoration: gpsInputDecoration(
                            context: context,
                            onPressed: _fillGpsFromDevice,
                            iconColor: const Color(0xFF0284C7),
                          ).copyWith(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),

                    // SECTION 2: Materi & Keterangan
                    SapSectionCard(
                      stepNumber: '2',
                      title: 'MATERI & KETERANGAN',
                      subtitle: 'Topik pembahasan keselamatan dan ringkasan arahan',
                      icon: Icons.menu_book_rounded,
                      accentColor: const Color(0xFF7C3AED),
                      children: [
                        const Text('JUDUL SAFETY TALK *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _title,
                          decoration: InputDecoration(
                            hintText: 'Contoh: Bahaya Blind Spot Unit HD & LV di Pit',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF7C3AED), size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),

                        const Text('RINGKASAN MATERI / KETERANGAN *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _remark,
                          minLines: 3,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Tuliskan poin penting yang disampaikan ke tim...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),

                    // SECTION 3: Dokumentasi Foto
                    SapSectionCard(
                      stepNumber: '3',
                      title: 'DOKUMENTASI FOTO KEGIATAN',
                      subtitle: 'Foto selfie pemateri dan foto seluruh peserta safety talk',
                      icon: Icons.camera_alt_rounded,
                      accentColor: const Color(0xFF16A34A),
                      children: [
                        _buildPhotoBox(
                          label: 'FOTO DIRI / PEMATERI *',
                          localPath: _selfImage,
                          remoteUrl: _existing?['fotoDiri']?.toString(),
                          onPick: () => _pickPhoto(isSelf: true),
                          onRemove: () => setState(() => _selfImage = null),
                        ),
                        const SizedBox(height: 14),
                        _buildPhotoBox(
                          label: 'FOTO KEGIATAN / PESERTA *',
                          localPath: _eventImage,
                          remoteUrl: _existing?['fotoKegiatan']?.toString(),
                          onPick: () => _pickPhoto(isSelf: false),
                          onRemove: () => setState(() => _eventImage = null),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: FilledButton.icon(
              onPressed: _isSaving ||
                      (_areaId == null ||
                          _locationId == null ||
                          _title.text.trim().isEmpty ||
                          _remark.text.trim().isEmpty ||
                          (_selfImage == null && _existing == null) ||
                          (_eventImage == null && _existing == null))
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      setState(() => _isSaving = true);
                      final area = _areaList.firstWhere((e) => e.key == _areaId).value.toString();
                      final benchmark = _locationList.firstWhere((e) => e.key == _locationId).value.toString();

                      try {
                        final insertData = <String, dynamic>{
                          'title': _title.text.trim(),
                          'remark': _remark.text.trim(),
                          'area_id': _areaId,
                          'location_id': _locationId,
                          'area': area,
                          'lokasi': benchmark,
                          'location_detail': _locationDetail.text.trim(),
                          'date': (_date ?? DateTime.now()).toIso8601String().substring(0, 10),
                          'time': _time ?? '08:00',
                          'self_image': _selfImage,
                          'event_image': _eventImage,
                          'image': _selfImage,
                          'repair_image': _eventImage,
                          'status': 0,
                          'company_id': _profile?.companyId,
                          'employee_id': _profile?.id,
                          'created_at': DateTime.now().toIso8601String(),
                          'updated_at': DateTime.now().toIso8601String(),
                        };

                        final localId = await _db.insert('safety_trans', insertData);

                        bool synced = false;
                        try {
                          synced = await syncTran(_db, _api, 'safety', localId);
                        } catch (_) {
                          synced = false;
                        }

                        if (!mounted) return;
                        setState(() => _isSaving = false);

                        OfflineSyncService.instance.refresh();

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              synced
                                  ? 'Safety Talk berhasil disimpan dan disinkronkan ke server.'
                                  : 'Safety Talk tersimpan di perangkat (Mode Offline). Akan disinkronkan otomatis saat online.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );

                        navigator.pop(true);
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => _isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Gagal menyimpan Safety Talk: $e'),
                            backgroundColor: const Color(0xFFDC2626),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DE8),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSaving ? 'Menyimpan...' : 'Simpan Safety Talk',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

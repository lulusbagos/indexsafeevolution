import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../widgets/button_app.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';

class P2HChecklistItem {
  final int id;
  final String name;
  final String group; // 'golA', 'golB', 'golC'
  String status; // 'GOOD' / 'NOT_GOOD'
  String? localPhotoPath;
  String? remotePhotoUrl;

  P2HChecklistItem({
    required this.id,
    required this.name,
    required this.group,
    this.status = 'GOOD',
    this.localPhotoPath,
    this.remotePhotoUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'photoUrl': remotePhotoUrl ?? localPhotoPath,
      };
}

class P2HFormPage extends StatefulWidget {
  const P2HFormPage({super.key});

  @override
  State<P2HFormPage> createState() => _P2HFormPageState();
}

class _P2HFormPageState extends State<P2HFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  final _picker = ImagePicker();

  // Controllers & FocusNodes
  final _noLambungCtrl = TextEditingController();
  final _merekCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _noLambungFocusNode = FocusNode();
  final _merekFocusNode = FocusNode();

  DateTime _tanggal = DateTime.now();
  TimeOfDay _waktu = TimeOfDay.now();

  String _jenisKendaraan = 'LIGHT VEHICLE';
  String _simperKimper = 'YA';
  File? _fotoSpeedometer;

  bool _isSubmitting = false;
  List<Map<String, dynamic>> _availableVehicles = [];
  bool _showInlineVehicleSuggestions = false;
  double _lastRecordedKm = 0.0;
  String? _lastRecordedKmDate;

  // 37 Web Checklist Questions
  static const List<String> _golAQuestions = [
    'Klakson/Horn',
    'Rem Tangan/Park Brake',
    'Masa Berlaku Stiker Komisioning/Commissioning Sticker Expired Date',
    'APAR',
    'Lampu Mundur Dan Alarm Mundur',
    'Radio Komunikasi',
    'Lampu Rotary',
    'Level Oli Kemudi/Level Oil Steering',
    'Sabuk Pengaman/Safety Belt',
    'Rem Kaki/Foot Brake',
    'Tebal Ban/Tyre Tread',
    'Lampu Depan/Head Light',
    'Baut Roda/Wheel Stud',
    'Lampu Belok Dan Lampu Belakang/Sign And Tail Lights',
    'Lampu Rem/Brake Light',
    'Kemudi/Steering',
  ];

  static const List<String> _golBQuestions = [
    'Kaca Depan/Windscreen',
    'Bendera Dan Bugywhip',
    'Level Oli Mesin/Engine Oil Level',
    'Level Oli Persneling/Clutch Oil Level',
    'Panel Gauge Dan Indikator',
    'Level Air/Water Level',
    'Level Minyak Rem/Brake Fluids Level',
    'Masa Servis/Service Due',
    'Level Air Radiator/Radiator Water Level',
    'Kotak P3K/First Aid Kit',
  ];

  static const List<String> _golCQuestions = [
    'Cairan Wiper/Windscreen Washer',
    'Rangka Pengaman Kabin',
    'Kerusakan Lain',
    'Kebersihan Luar Mobil/Exterior Clean',
    'Pintu-pintu/Doors',
    'Aki/Battery Pack',
    'Ban Serep/Spare Tyre',
    'Kebersihan Dalam Mobil/Interior Clean',
    'Segitiga Pengaman/Triangle Safety Cone',
    'Dongkrak/Jack',
    'Kaca/Mirror',
  ];

  final List<P2HChecklistItem> _golAItems = [];
  final List<P2HChecklistItem> _golBItems = [];
  final List<P2HChecklistItem> _golCItems = [];

  bool _isGolAExpanded = true;
  bool _isGolBExpanded = false;
  bool _isGolCExpanded = false;

  final List<String> _vehicleTypes = [
    'LIGHT VEHICLE',
    'DUMP TRUCK',
    'HEAVY EQUIPMENT',
    'BUS / MANTRIP',
    'MOTORCYCLE',
    'OTHER'
  ];

  @override
  void initState() {
    super.initState();
    _initChecklists();
    _loadVehicles();
  }

  @override
  void dispose() {
    _noLambungCtrl.dispose();
    _merekCtrl.dispose();
    _kmCtrl.dispose();
    _noLambungFocusNode.dispose();
    _merekFocusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _initChecklists() {
    for (int i = 0; i < _golAQuestions.length; i++) {
      _golAItems.add(P2HChecklistItem(
        id: i + 1,
        name: _golAQuestions[i],
        group: 'golA',
      ));
    }
    for (int i = 0; i < _golBQuestions.length; i++) {
      _golBItems.add(P2HChecklistItem(
        id: i + 1,
        name: _golBQuestions[i],
        group: 'golB',
      ));
    }
    for (int i = 0; i < _golCQuestions.length; i++) {
      _golCItems.add(P2HChecklistItem(
        id: i + 1,
        name: _golCQuestions[i],
        group: 'golC',
      ));
    }
  }

  Future<void> _loadVehicles() async {
    try {
      // 1. Load from SQLite vehicle_masters
      final cached = await _db.rawQuery('''
        SELECT code, name, type FROM vehicle_masters 
        WHERE deleted_at IS NULL 
        ORDER BY code ASC
      ''');

      final list = <Map<String, dynamic>>[];
      for (var row in cached) {
        list.add({
          'noLambung': row['code']?.toString() ?? '',
          'merek': row['name']?.toString() ?? '',
          'jenisKendaraan': row['type']?.toString() ?? 'LIGHT VEHICLE',
          'lastKm': 0.0,
        });
      }

      // 2. Also check if p2h_vehicles table has extra entries & last_km
      try {
        final p2hVehs = await _db.rawQuery('SELECT no_lambung, merek, jenis_kendaraan, last_km FROM p2h_vehicles');
        for (var row in p2hVehs) {
          final nl = row['no_lambung']?.toString() ?? '';
          final km = double.tryParse(row['last_km']?.toString() ?? '0') ?? 0.0;
          final idx = list.indexWhere((x) => x['noLambung'].toString().toLowerCase() == nl.toLowerCase());
          if (idx >= 0) {
            list[idx]['lastKm'] = km;
          } else if (nl.isNotEmpty) {
            list.add({
              'noLambung': nl,
              'merek': row['merek']?.toString() ?? '',
              'jenisKendaraan': row['jenis_kendaraan']?.toString() ?? 'LIGHT VEHICLE',
              'lastKm': km,
            });
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _availableVehicles = list;
        });
      }

      // 3. Background fetch online vehicles to update cache
      _fetchOnlineVehicles();
    } catch (e) {
      debugPrint('[P2HForm] Error loading vehicles: $e');
    }
  }

  Future<void> _fetchOnlineVehicles() async {
    try {
      final res = await _api.dio.get('/p2h/vehicles');
      if (res.data != null && res.data['data'] is List) {
        final onlineList = res.data['data'] as List;
        for (var item in onlineList) {
          if (item is Map) {
            final nl = item['noLambung']?.toString().replaceAll("'", "''") ?? '';
            final mrk = item['merek']?.toString().replaceAll("'", "''") ?? '';
            final jns = item['jenisKendaraan']?.toString().replaceAll("'", "''") ?? 'LIGHT VEHICLE';
            final km = double.tryParse(item['lastKm']?.toString() ?? '0') ?? 0.0;

            if (nl.isNotEmpty) {
              await _db.execute('''
                INSERT OR REPLACE INTO p2h_vehicles (no_lambung, merek, jenis_kendaraan, last_km) 
                VALUES ('$nl', '$mrk', '$jns', $km)
              ''');
            }
          }
        }
        _loadVehicles();
      }
    } catch (_) {}
  }

  Future<void> _lookupLastRecordedKm(String noLambung) async {
    final cleanNl = noLambung.trim().toLowerCase();
    if (cleanNl.isEmpty) {
      setState(() {
        _lastRecordedKm = 0.0;
        _lastRecordedKmDate = null;
      });
      return;
    }

    // 1. Check local SQLite p2h_trans
    double localMaxKm = 0.0;
    String? localDate;
    try {
      final localRows = await _db.rawQuery('''
        SELECT km, date FROM p2h_trans 
        WHERE LOWER(no_lambung) = ? 
        ORDER BY date DESC, time DESC, id DESC 
        LIMIT 1
      ''', [cleanNl]);
      if (localRows.isNotEmpty && localRows.first['km'] != null) {
        localMaxKm = double.tryParse(localRows.first['km'].toString()) ?? 0.0;
        localDate = localRows.first['date']?.toString();
      }
    } catch (_) {}

    // 2. Check cached in _availableVehicles
    double cachedKm = 0.0;
    for (var v in _availableVehicles) {
      if (v['noLambung'].toString().toLowerCase() == cleanNl && v['lastKm'] != null) {
        cachedKm = double.tryParse(v['lastKm'].toString()) ?? 0.0;
        break;
      }
    }

    double bestKm = localMaxKm > cachedKm ? localMaxKm : cachedKm;

    // 3. Online fetch from /p2h/last-km
    try {
      final res = await _api.dio.get('/p2h/last-km', queryParameters: {'noLambung': cleanNl});
      if (res.data != null && res.data['lastKm'] != null) {
        final onlineKm = double.tryParse(res.data['lastKm'].toString()) ?? 0.0;
        if (onlineKm > 0) {
          bestKm = onlineKm;
          localDate = res.data['lastDate']?.toString();
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _lastRecordedKm = bestKm;
        _lastRecordedKmDate = localDate;
      });
    }
  }

  void _selectVehicle(Map<String, dynamic> veh) {
    final km = double.tryParse(veh['lastKm']?.toString() ?? '0') ?? 0.0;
    setState(() {
      _noLambungCtrl.text = veh['noLambung']?.toString() ?? '';
      _merekCtrl.text = veh['merek']?.toString() ?? '';

      final jns = veh['jenisKendaraan']?.toString().toUpperCase() ?? 'LIGHT VEHICLE';
      if (_vehicleTypes.contains(jns)) {
        _jenisKendaraan = jns;
      } else {
        _jenisKendaraan = 'LIGHT VEHICLE';
      }
      if (km > 0) {
        _lastRecordedKm = km;
      }
      _showInlineVehicleSuggestions = false;
    });
    _lookupLastRecordedKm(_noLambungCtrl.text);
  }

  void _onSelectNewUnit(String newUnit) {
    setState(() {
      _noLambungCtrl.text = newUnit.toUpperCase();
      _merekCtrl.text = '';
      _jenisKendaraan = 'LIGHT VEHICLE';
      _lastRecordedKm = 0.0;
      _lastRecordedKmDate = null;
      _showInlineVehicleSuggestions = false;
    });
    _merekFocusNode.requestFocus();
  }

  void _openVehiclePickerModal(BuildContext context) {
    final searchCtrl = TextEditingController(text: _noLambungCtrl.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? _availableVehicles
                : _availableVehicles.where((v) {
                    final nl = v['noLambung']?.toString().toLowerCase() ?? '';
                    final mrk = v['merek']?.toString().toLowerCase() ?? '';
                    return nl.contains(query) || mrk.contains(query);
                  }).toList();

            final isExactMatch = _availableVehicles.any((v) => v['noLambung'].toString().toLowerCase() == query);

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.directions_car_rounded, color: Color(0xFF0284C7), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih Kendaraan',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              'Cari dari master atau tambah unit baru',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: searchCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Cari No. Lambung / Merek...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF0284C7), size: 20),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setModalState(() {
                                    searchCtrl.clear();
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                  ),
                  if (searchCtrl.text.trim().isNotEmpty && !isExactMatch)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                      child: InkWell(
                        onTap: () {
                          final customVal = searchCtrl.text.trim().toUpperCase();
                          _onSelectNewUnit(customVal);
                          Navigator.pop(modalCtx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle, color: Color(0xFFD97706), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tambah "${searchCtrl.text.trim().toUpperCase()}" Sebagai Unit Baru',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB45309),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const Divider(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'Tidak ada kendaraan yang cocok.',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final v = filtered[i];
                              final km = (v['lastKm'] ?? 0) as num;
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF0284C7), size: 20),
                                ),
                                title: Text(
                                  v['noLambung']?.toString() ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${v['merek']} • ${v['jenisKendaraan']}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                                trailing: km > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${NumberFormat("#,##0", "id_ID").format(km)} KM',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                        ),
                                      )
                                    : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                onTap: () {
                                  _selectVehicle(v);
                                  Navigator.pop(modalCtx);
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

  void _autoFillAll(String status) {
    setState(() {
      for (var item in _golAItems) {
        item.status = status;
      }
      for (var item in _golBItems) {
        item.status = status;
      }
      for (var item in _golCItems) {
        item.status = status;
      }
    });

    final label = status == 'GOOD' ? 'Semua BAIK' : 'Semua RUSAK';
    SnackBarMsg.info(context, 'Checklist diatur ke: $label');
  }

  Future<void> _pickSpeedoImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (picked != null && mounted) {
        setState(() {
          _fotoSpeedometer = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) SnackBarMsg.danger(context, 'Gagal mengambil foto: $e');
    }
  }

  Future<void> _pickDefectImage(P2HChecklistItem item, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (picked != null && mounted) {
        setState(() {
          item.localPhotoPath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) SnackBarMsg.danger(context, 'Gagal mengambil foto kerusakan: $e');
    }
  }

  Future<void> _submitP2H() async {
    // 0. Back-Date Validation (Strictly No Past Dates)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reportDate = DateTime(_tanggal.year, _tanggal.month, _tanggal.day);
    if (reportDate.isBefore(today)) {
      SnackBarMsg.danger(context, 'Pengisian P2H tidak boleh back-date (tanggal lampau). Silakan pilih tanggal hari ini.');
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    // 1. Form Validation
    final noLambung = _noLambungCtrl.text.trim().toUpperCase();
    if (noLambung.isEmpty) {
      SnackBarMsg.danger(context, 'No. Lambung Kendaraan wajib diisi.');
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    final merek = _merekCtrl.text.trim();
    if (merek.isEmpty) {
      SnackBarMsg.danger(context, 'Merek / Tipe Kendaraan wajib diisi.');
      _scrollCtrl.animateTo(100, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    final kmVal = double.tryParse(_kmCtrl.text.replaceAll(',', '.')) ?? 0;
    if (_kmCtrl.text.trim().isEmpty || kmVal <= 0) {
      SnackBarMsg.danger(context, 'Odometer / Kilometer harus diisi dengan angka valid.');
      _scrollCtrl.animateTo(180, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    // Odometer must be greater than previous recorded KM
    if (_lastRecordedKm > 0 && kmVal <= _lastRecordedKm) {
      SnackBarMsg.danger(
        context,
        'Odometer baru (${NumberFormat("#,##0", "id_ID").format(kmVal)} KM) harus lebih besar dari KM sebelumnya (${NumberFormat("#,##0", "id_ID").format(_lastRecordedKm)} KM). Pastikan angka kilometer tidak salah!',
      );
      _scrollCtrl.animateTo(180, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    final speedoExists = _fotoSpeedometer != null && await _fotoSpeedometer!.exists();
    if (!mounted) return;
    if (!speedoExists) {
      SnackBarMsg.danger(context, 'Foto Speedometer WAJIB dilampirkan.');
      _scrollCtrl.animateTo(250, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    // 2. Validate Defect Photos (Mandatory for any item with status NOT_GOOD)
    final missingPhotoA = _golAItems.where((x) => x.status == 'NOT_GOOD' && (x.localPhotoPath == null || x.localPhotoPath!.isEmpty)).toList();
    if (missingPhotoA.isNotEmpty) {
      setState(() => _isGolAExpanded = true);
      SnackBarMsg.danger(context, 'GOLONGAN A: Foto kerusakan wajib untuk "${missingPhotoA.first.name}".');
      return;
    }

    final missingPhotoB = _golBItems.where((x) => x.status == 'NOT_GOOD' && (x.localPhotoPath == null || x.localPhotoPath!.isEmpty)).toList();
    if (missingPhotoB.isNotEmpty) {
      setState(() => _isGolBExpanded = true);
      SnackBarMsg.danger(context, 'GOLONGAN B: Foto kerusakan wajib untuk "${missingPhotoB.first.name}".');
      return;
    }

    final missingPhotoC = _golCItems.where((x) => x.status == 'NOT_GOOD' && (x.localPhotoPath == null || x.localPhotoPath!.isEmpty)).toList();
    if (missingPhotoC.isNotEmpty) {
      setState(() => _isGolCExpanded = true);
      SnackBarMsg.danger(context, 'GOLONGAN C: Foto kerusakan wajib untuk "${missingPhotoC.first.name}".');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Copy photos to permanent app directory for offline safety
      final appDir = await getApplicationDocumentsDirectory();
      final p2hDir = Directory('${appDir.path}/p2h_photos');
      if (!await p2hDir.exists()) await p2hDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Copy speedo photo
      final permanentSpeedoPath = '${p2hDir.path}/speedo_$timestamp.jpg';
      await _fotoSpeedometer!.copy(permanentSpeedoPath);

      // Copy defect photos
      for (var item in [..._golAItems, ..._golBItems, ..._golCItems]) {
        if (item.status == 'NOT_GOOD' && item.localPhotoPath != null) {
          final orig = File(item.localPhotoPath!);
          if (await orig.exists()) {
            final targetPath = '${p2hDir.path}/${item.group}_${item.id}_$timestamp.jpg';
            await orig.copy(targetPath);
            item.localPhotoPath = targetPath;
          }
        }
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_tanggal);
      final timeStr = '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}';
      final jsonA = jsonEncode(_golAItems.map((e) => e.toJson()).toList());
      final jsonB = jsonEncode(_golBItems.map((e) => e.toJson()).toList());
      final jsonC = jsonEncode(_golCItems.map((e) => e.toJson()).toList());

      // 3. Save directly to SQLite (ensures 100% offline persistence)
      final localRow = <String, dynamic>{
        'code': 'P2H-$timestamp',
        'title': 'P2H Unit $noLambung',
        'date': dateStr,
        'time': timeStr,
        'no_lambung': noLambung,
        'merek': merek,
        'jenis_kendaraan': _jenisKendaraan,
        'km': kmVal,
        'simper_kimper': _simperKimper,
        'simper': _simperKimper == 'YA' ? 1 : 0,
        'image': permanentSpeedoPath,
        'foto_speedometer': permanentSpeedoPath,
        'gol_a_json': jsonA,
        'gol_b_json': jsonB,
        'gol_c_json': jsonC,
        'company_id': _profile?.companyId,
        'employee_id': _profile?.id ?? 0,
        'sync_id': null, // null means pending sync
        'created_at': DateTime.now().toString(),
        'updated_at': DateTime.now().toString(),
      };

      final tranId = await _db.insert('p2h_trans', localRow);

      // Cache vehicle into SQLite p2h_vehicles with last_km
      try {
        await _db.execute('''
          INSERT INTO p2h_vehicles (no_lambung, merek, jenis_kendaraan, last_km) 
          VALUES ('$noLambung', '$merek', '$_jenisKendaraan', $kmVal)
        ''');
      } catch (_) {}

      // 4. Check Connectivity & Sync
      final isOnline = OfflineSyncService.instance.state.value.isOnline;
      if (isOnline) {
        final synced = await syncTran(_db, _api, 'p2h', tranId);
        if (synced && mounted) {
          SnackBarMsg.success(context, 'Laporan P2H berhasil dikirim dan tersinkronisasi!');
          Navigator.pop(context, true);
          return;
        }
      }

      // If offline or sync failed, notify offline saved
      await OfflineSyncService.instance.refreshPendingCount();
      if (mounted) {
        SnackBarMsg.info(
          context,
          'Laporan P2H tersimpan di perangkat (Mode Offline). Akan otomatis disinkronkan saat terhubung ke internet.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('[P2HForm] Submit error: $e');
      if (mounted) {
        SnackBarMsg.danger(context, 'Terjadi kesalahan saat menyimpan data: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = OfflineSyncService.instance.state.value.isOnline;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(title: 'P2H Kendaraan', back: 1),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Banner Matching Web
                _buildHeaderBanner(isOnline),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Tanggal & Waktu
                      _buildCard(
                        title: 'WAKTU & PEMERIKSA',
                        icon: Icons.calendar_today_rounded,
                        accentColor: const Color(0xFF0284C7),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDatePicker(context),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTimePicker(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildReadOnlyField(
                                  label: 'NIK Pemeriksa',
                                  value: _profile?.noNik ?? '00000',
                                  icon: Icons.badge_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildReadOnlyField(
                                  label: 'Nama Pemeriksa',
                                  value: _profile?.namaLengkap ?? 'Pemeriksa',
                                  icon: Icons.person_outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section 2: Informasi Kendaraan
                      _buildCard(
                        title: 'INFORMASI KENDARAAN',
                        icon: Icons.directions_car_rounded,
                        accentColor: const Color(0xFF0284C7),
                        children: [
                          // No Lambung Searchable
                          const Text(
                            'No. Lambung Kendaraan *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _noLambungCtrl,
                                  focusNode: _noLambungFocusNode,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'Ketik No. Lambung (Misal: 007)...',
                                    prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFF0284C7), size: 20),
                                    suffixIcon: _noLambungCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              setState(() {
                                                _noLambungCtrl.clear();
                                                _showInlineVehicleSuggestions = false;
                                                _lastRecordedKm = 0.0;
                                                _lastRecordedKmDate = null;
                                              });
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _showInlineVehicleSuggestions = val.trim().isNotEmpty;
                                    });
                                    if (val.trim().isNotEmpty) {
                                      _lookupLastRecordedKm(val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _openVehiclePickerModal(context),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.search, color: Colors.white, size: 18),
                                      SizedBox(width: 4),
                                      Text(
                                        'Pilih',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Smart Inline Suggestions Card (Exact Web Experience)
                          if (_showInlineVehicleSuggestions && _noLambungCtrl.text.trim().isNotEmpty) ...[
                            Builder(
                              builder: (ctx) {
                                final query = _noLambungCtrl.text.trim().toLowerCase();
                                final matches = _availableVehicles.where((v) {
                                  final nl = v['noLambung']?.toString().toLowerCase() ?? '';
                                  final mrk = v['merek']?.toString().toLowerCase() ?? '';
                                  return nl.contains(query) || mrk.contains(query);
                                }).toList();
                                final isExactMatch = _availableVehicles.any((v) => v['noLambung'].toString().toLowerCase() == query);

                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // If no exact match, offer to Add as New Unit
                                      if (!isExactMatch)
                                        InkWell(
                                          onTap: () => _onSelectNewUnit(_noLambungCtrl.text.trim()),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.add_circle, color: Color(0xFFD97706), size: 18),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Tambah "${_noLambungCtrl.text.trim().toUpperCase()}" Sebagai Unit Baru',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309), fontSize: 12.5),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      // Up to 5 matching vehicles
                                      ...matches.take(5).map((v) {
                                        final km = (v['lastKm'] ?? 0) as num;
                                        return InkWell(
                                          onTap: () => _selectVehicle(v),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                            decoration: BoxDecoration(
                                              border: Border(top: BorderSide(color: Colors.grey.shade200)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.local_shipping_outlined, color: Color(0xFF0284C7), size: 18),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        v['noLambung']?.toString() ?? '',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                                      ),
                                                      Text(
                                                        '${v['merek']} • ${v['jenisKendaraan']}',
                                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (km > 0)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE0F2FE),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      '${NumberFormat("#,##0", "id_ID").format(km)} KM',
                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                      InkWell(
                                        onTap: () => setState(() => _showInlineVehicleSuggestions = false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                                          ),
                                          child: const Text('Tutup Saran', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Merek & Jenis
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Merek / Tipe *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _merekCtrl,
                                      focusNode: _merekFocusNode,
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        hintText: 'Misal: TRITON 2.5L',
                                        prefixIcon: const Icon(Icons.branding_watermark_outlined, color: Color(0xFF0284C7), size: 20),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
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
                                    const Text('Jenis Kendaraan *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: _jenisKendaraan,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF0284C7), size: 20),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                      ),
                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                      items: _vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12, overflow: TextOverflow.ellipsis)))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _jenisKendaraan = val);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Odometer & SIMPER
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Odometer / KM *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _kmCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                      decoration: InputDecoration(
                                        hintText: _lastRecordedKm > 0 ? '> ${_lastRecordedKm.toStringAsFixed(0)}' : 'Misal: 45000',
                                        prefixIcon: const Icon(Icons.speed_rounded, color: Color(0xFF0284C7), size: 20),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                      ),
                                      onChanged: (val) => setState(() {}),
                                    ),
                                    if (_lastRecordedKm > 0) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF86EFAC)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.history, color: Color(0xFF16A34A), size: 13),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'KM Sebelumnya: ${NumberFormat("#,##0", "id_ID").format(_lastRecordedKm)} KM${_lastRecordedKmDate != null ? ' ($_lastRecordedKmDate)' : ''}',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (_lastRecordedKm > 0 && _kmCtrl.text.isNotEmpty && (double.tryParse(_kmCtrl.text.replaceAll(',', '.')) ?? 0) <= _lastRecordedKm) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFFCA5A5)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 13),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Wajib > ${_lastRecordedKm.toStringAsFixed(0)} KM!',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('SIMPER / KIMPER Aktif? *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: _simperKimper,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.credit_card_rounded, color: Color(0xFF0284C7), size: 20),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                      ),
                                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                                      items: const [
                                        DropdownMenuItem(value: 'YA', child: Text('YA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                        DropdownMenuItem(value: 'TIDAK', child: Text('TIDAK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _simperKimper = val);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Foto Speedometer (Mandatory)
                          _buildSpeedometerUploadCard(),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Section 3: Checklist Kondisi Unit & Quick Actions
                      _buildChecklistHeader(),

                      const SizedBox(height: 12),

                      // Golongan A Accordion
                      _buildGroupAccordion(
                        title: 'GOLONGAN A (Kritis - 16 Item)',
                        badgeText: 'KRITIS',
                        badgeColor: const Color(0xFFE11D48),
                        bgColor: const Color(0xFFFFF1F2),
                        isExpanded: _isGolAExpanded,
                        onToggle: () => setState(() => _isGolAExpanded = !_isGolAExpanded),
                        items: _golAItems,
                      ),

                      const SizedBox(height: 12),

                      // Golongan B Accordion
                      _buildGroupAccordion(
                        title: 'GOLONGAN B (Penting - 10 Item)',
                        badgeText: 'PENTING',
                        badgeColor: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                        isExpanded: _isGolBExpanded,
                        onToggle: () => setState(() => _isGolBExpanded = !_isGolBExpanded),
                        items: _golBItems,
                      ),

                      const SizedBox(height: 12),

                      // Golongan C Accordion
                      _buildGroupAccordion(
                        title: 'GOLONGAN C (Umum - 11 Item)',
                        badgeText: 'UMUM',
                        badgeColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFF0F9FF),
                        isExpanded: _isGolCExpanded,
                        onToggle: () => setState(() => _isGolCExpanded = !_isGolCExpanded),
                        items: _golCItems,
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar Submit Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: buttonApp(
                  label: _isSubmitting ? 'MENYIMPAN LAPORAN...' : 'KIRIM LAPORAN P2H',
                  bgColor: const Color(0xFF0284C7),
                  onPressed: _isSubmitting ? null : _submitP2H,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Sub-Widgets ---

  Widget _buildHeaderBanner(bool isOnline) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.white.withValues(alpha: 0.25) : Colors.orange.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online Sync' : 'Mode Offline Siap',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified_user_rounded, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 38),
          const SizedBox(height: 6),
          const Text(
            'P2H - PEMERIKSAAN KENDARAAN',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pemeriksaan kondisi unit dan kelayakan operasional harian sebelum bekerja.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 0.8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({required String label, required String value, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tanggal *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final picked = await showDatePicker(
              context: context,
              initialDate: _tanggal.isBefore(today) ? today : _tanggal,
              firstDate: today, // STRICT: No past dates / back-dates!
              lastDate: today.add(const Duration(days: 7)),
              helpText: 'PILIH TANGGAL PEMERIKSAAN P2H',
            );
            if (picked != null) setState(() => _tanggal = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_tanggal),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Waktu *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _waktu,
            );
            if (picked != null) setState(() => _waktu = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedometerUploadCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Foto Speedometer *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            if (_fotoSpeedometer != null)
              GestureDetector(
                onTap: () => setState(() => _fotoSpeedometer = null),
                child: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_fotoSpeedometer == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4), style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                const Icon(Icons.speed_rounded, color: Color(0xFF0284C7), size: 36),
                const SizedBox(height: 8),
                const Text(
                  'Unggah Foto Speedometer Terbaru',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Wajib melampirkan foto angka odometer / speedometer yang jelas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded, size: 16),
                      label: const Text('Kamera', style: TextStyle(fontSize: 12)),
                      onPressed: () => _pickSpeedoImage(ImageSource.camera),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.photo_library_rounded, size: 16),
                      label: const Text('Galeri', style: TextStyle(fontSize: 12)),
                      onPressed: () => _pickSpeedoImage(ImageSource.gallery),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade400, width: 1.5),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _fotoSpeedometer!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                        SizedBox(width: 6),
                        Text('Foto terpasang', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.replay_rounded, size: 14, color: Color(0xFF0284C7)),
                      label: const Text('Ganti', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7))),
                      onPressed: () => _pickSpeedoImage(ImageSource.camera),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChecklistHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'CHECKLIST KONDISI UNIT',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
            letterSpacing: 0.3,
          ),
        ),
        Row(
          children: [
            InkWell(
              onTap: () => _autoFillAll('GOOD'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done_all_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Semua BAIK', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _autoFillAll('NOT_GOOD'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFE11D48)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF43F5E).withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Semua RUSAK', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupAccordion({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color bgColor,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<P2HChecklistItem> items,
  }) {
    final badCount = items.where((x) => x.status == 'NOT_GOOD').length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isExpanded ? badgeColor.withValues(alpha: 0.5) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: isExpanded
                    ? const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14))
                    : BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ),
                  if (badCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badCount Rusak',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ),

          // Items
          if (isExpanded)
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (ctx, i) {
                final item = items[i];
                return _buildChecklistItem(item, i);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(P2HChecklistItem item, int index) {
    final isGood = item.status == 'GOOD';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${index + 1}. ${item.name}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Toggle BAIK / RUSAK
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      item.status = 'GOOD';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isGood ? const Color(0xFF10B981) : Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                      border: Border.all(
                        color: isGood ? const Color(0xFF10B981) : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      'BAIK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isGood ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      item.status = 'NOT_GOOD';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: !isGood ? const Color(0xFFE11D48) : Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      border: Border.all(
                        color: !isGood ? const Color(0xFFE11D48) : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      'RUSAK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: !isGood ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Defect Photo Upload if NOT_GOOD
        if (!isGood) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDA4AF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.camera_alt_rounded, color: Color(0xFFE11D48), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Foto Kerusakan (Wajib)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                        ),
                      ],
                    ),
                    if (item.localPhotoPath != null)
                      GestureDetector(
                        onTap: () => setState(() => item.localPhotoPath = null),
                        child: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (item.localPhotoPath == null)
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, size: 14),
                        label: const Text('Kamera', style: TextStyle(fontSize: 11)),
                        onPressed: () => _pickDefectImage(item, ImageSource.camera),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE11D48),
                          side: const BorderSide(color: Color(0xFFE11D48)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 14),
                        label: const Text('Galeri', style: TextStyle(fontSize: 11)),
                        onPressed: () => _pickDefectImage(item, ImageSource.gallery),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(item.localPhotoPath!),
                          height: 60,
                          width: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text('Foto terlampir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _pickDefectImage(item, ImageSource.camera),
                        child: const Text('Ganti', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7))),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

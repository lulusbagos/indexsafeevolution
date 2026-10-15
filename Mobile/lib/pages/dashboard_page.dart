import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/incident_news_model.dart';
import '../models/link_model.dart';
import '../services/api.dart';
import '../services/preference.dart';
import '../utils/links.dart';
import '../widgets/snackbar_msg.dart';
import 'global_search_page.dart';
import 'hazard/hazard_hub_page.dart';
import 'menu/extra_page.dart';
import 'menu/ohs_page.dart';
import 'menu/sap_page.dart';
import 'notif_page.dart';
import 'safety_updates_page.dart';

class _HomeModuleCard extends StatelessWidget {
  const _HomeModuleCard({
    required this.title,
    required this.imagePath,
    required this.labelColor,
    required this.onTap,
    this.iconHeight = 68,
  });

  final String title;
  final String imagePath;
  final Color labelColor;
  final VoidCallback onTap;
  final double iconHeight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 126,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD9E1F2)),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withValues(alpha: .06),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Image.asset(
                    imagePath,
                    height: iconHeight,
                    width: 82,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 32,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: labelColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeNotificationButton extends StatelessWidget {
  const _HomeNotificationButton({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? 'Notifikasi, $count belum dibaca' : 'Notifikasi',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5FF),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFDCE6FF)),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 25,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 19, minHeight: 19),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapHazardItem {
  final int id;
  final String title;
  final String area;
  final String level; // Kritis, Tinggi, Sedang, Rendah
  final String color;
  String status; // Open, On Progress (never Closed in active heatmap)
  final String statusColor;
  double lat;
  double lng;
  final String photo;
  final String notes;
  final DateTime date;
  final String pelapor;
  final String pja;
  final String kategori;

  MapHazardItem({
    required this.id,
    required this.title,
    required this.area,
    required this.level,
    required this.color,
    required this.status,
    required this.statusColor,
    required this.lat,
    required this.lng,
    required this.photo,
    required this.notes,
    required this.date,
    this.pelapor = 'Safety Officer',
    this.pja = 'Supervisor Lapangan',
    this.kategori = 'Kondisi Tidak Aman (KTA)',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'area': area,
        'level': level,
        'color': color,
        'status': status,
        'statusColor': statusColor,
        'lat': lat,
        'lng': lng,
        'photo': photo,
        'notes': notes,
        'date':
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
        'pelapor': pelapor,
        'pja': pja,
        'kategori': kategori,
      };
}

Future<void> _injectCurrentPosition(WebViewController controller) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await controller.runJavaScript(
      'if(window.setUserLocation) window.setUserLocation(${position.latitude}, ${position.longitude}, ${position.accuracy});',
    );
  } catch (error) {
    debugPrint('Gagal menampilkan posisi pengguna pada heatmap: $error');
  }
}

class _FullscreenHazardMapPage extends StatefulWidget {
  const _FullscreenHazardMapPage({
    required this.html,
    required this.onCloseHazard,
    required this.onShowDetail,
    this.initialMode = 'heatmap',
    this.onModeChanged,
  });

  final String html;
  final Function(BuildContext context, int id) onCloseHazard;
  final Function(BuildContext context, int id) onShowDetail;
  final String initialMode;
  final ValueChanged<String>? onModeChanged;

  @override
  State<_FullscreenHazardMapPage> createState() =>
      _FullscreenHazardMapPageState();
}

class _FullscreenHazardMapPageState extends State<_FullscreenHazardMapPage> {
  late final WebViewController _controller;
  late String _mapMode;

  @override
  void initState() {
    super.initState();
    _mapMode = widget.initialMode;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'HazardBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          try {
            final data = jsonDecode(msg.message);
            final action = data['action']?.toString();
            final id = data['id'] is int
                ? data['id'] as int
                : int.tryParse(data['id']?.toString() ?? '0') ?? 0;
            if (action == 'detail') {
              widget.onShowDetail(context, id);
            } else if (action == 'close') {
              widget.onCloseHazard(context, id);
            }
          } catch (e) {
            debugPrint('Error handling HazardBridge message: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _injectCurrentPosition(_controller),
        ),
      )
      ..loadHtmlString(widget.html);
  }

  void _onSelectMode(String mode) {
    if (_mapMode == mode) return;
    setState(() => _mapMode = mode);
    _controller.runJavaScript(
      "if(window.setMapMode) window.setMapMode('$mode');",
    );
    widget.onModeChanged?.call(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: WebViewWidget(
                controller: _controller,
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
              ),
            ),
          ),
          // Tombol Kembali (Back Button)
          Positioned(
            top: 14,
            left: 14,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                elevation: 6,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded,
                            color: Color(0xFF1D4ED8), size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Kembali',
                          style: TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Segmented Switcher di Fullscreen: Heatmap | Titik | Off
          Positioned(
            top: 14,
            right: 14,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                elevation: 6,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFullscreenModeButton('heatmap', 'Heatmap'),
                      _buildFullscreenModeButton('points', 'Titik'),
                      _buildFullscreenModeButton('off', 'Off'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Tombol Lokasi Saya di Fullscreen (Kanan Bawah)
          Positioned(
            bottom: 24,
            right: 16,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    _controller.runJavaScript(
                      'if(window.locateMe) window.locateMe();',
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.my_location_rounded,
                      color: Color(0xFF1D4ED8),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenModeButton(String key, String label) {
    final isSelected = _mapMode == key;
    final isOff = key == 'off';
    return InkWell(
      onTap: () => _onSelectMode(key),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isOff ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isOff ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8))
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _profile = PreferenceService.getProfile();
  final _api = ApiService();
  final _hazardMapCtrl = WebViewController();
  final List<LinkMenuModel> _rawData = [
    ...listMenuSap,
    ...listMenuOhs1,
    ...listMenuOhs2,
    ...listMenuExtra
  ];
  final List<String> _searchList = [];
  String _searchText = '';

  // Banner State
  static List<IncidentNewsModel> _cachedBanners = [];
  List<IncidentNewsModel> _homeBanners = List.from(_cachedBanners);
  bool _isLoadingBanners = _cachedBanners.isEmpty;
  int _currentBannerIndex = 0;
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;

  // Notification State
  int _notifCount = PreferenceService.getNotif();

  // Heatmap & Radar Proximity State ('heatmap', 'points', 'off')
  String _hazardMapMode = 'heatmap';
  StreamSubscription<Position>? _positionStreamSub;
  Position? _lastUserPosition;
  bool _hasPlacedNearbyDemoHazard = false;
  MapHazardItem? _nearbyAlertHazard;
  double _nearbyDistance = 0;
  DateTime? _lastAlertTime;

  // Daftar hazard belum closed (30 hari terakhir)
  late List<MapHazardItem> _unclosedHazards;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _unclosedHazards = [
      MapHazardItem(
        id: 101,
        title: 'Tumpahan oli di workshop',
        area: 'Workshop LV',
        level: 'Tinggi',
        color: '#ef4444',
        status: 'On Progress',
        statusColor: '#f59e0b',
        lat: 1.2118,
        lng: 117.2198,
        photo:
            'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=520&q=80',
        notes: 'Potensi terpeleset dan kontaminasi area kerja.',
        date: now.subtract(const Duration(days: 3)),
        pelapor: 'Ahmad Ridwan',
        pja: 'Budi Santoso',
        kategori: 'Kondisi Tidak Aman (KTA)',
      ),
      MapHazardItem(
        id: 102,
        title: 'Material loose di hauling road',
        area: 'Hauling Road KM 4',
        level: 'Sedang',
        color: '#f59e0b',
        status: 'Open',
        statusColor: '#ef4444',
        lat: 1.1997,
        lng: 117.2331,
        photo:
            'https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=520&q=80',
        notes: 'Butuh housekeeping dan rambu sementara.',
        date: now.subtract(const Duration(days: 7)),
        pelapor: 'Joko Susilo',
        pja: 'Hendra Wijaya',
        kategori: 'Kondisi Tidak Aman (KTA)',
      ),
      MapHazardItem(
        id: 103,
        title: 'Area kerja tanpa barricade',
        area: 'Pit Selatan',
        level: 'Kritis',
        color: '#b91c1c',
        status: 'Open',
        statusColor: '#ef4444',
        lat: 1.1914,
        lng: 117.2145,
        photo:
            'https://images.unsplash.com/photo-1516937941344-00b4e0337589?auto=format&fit=crop&w=520&q=80',
        notes: 'Perlu isolasi area sebelum aktivitas lanjut.',
        date: now.subtract(const Duration(days: 12)),
        pelapor: 'Dedi Kurniawan',
        pja: 'Agus Pratama',
        kategori: 'Kondisi Tidak Aman (KTA)',
      ),
      MapHazardItem(
        id: 105,
        title: 'Debu tinggi di crusher',
        area: 'Crusher Area',
        level: 'Sedang',
        color: '#f97316',
        status: 'On Progress',
        statusColor: '#f59e0b',
        lat: 1.2071,
        lng: 117.2462,
        photo:
            'https://images.unsplash.com/photo-1518709268805-4e9042af2176?auto=format&fit=crop&w=520&q=80',
        notes: 'Cek water spray dan penggunaan respirator.',
        date: now.subtract(const Duration(days: 18)),
        pelapor: 'Siti Rahma',
        pja: 'Bambang Irawan',
        kategori: 'Tindakan Tidak Aman (TTA)',
      ),
      MapHazardItem(
        id: 106,
        title: 'Genangan dekat panel listrik',
        area: 'Fuel Station',
        level: 'Kritis',
        color: '#dc2626',
        status: 'Open',
        statusColor: '#ef4444',
        lat: 1.2232,
        lng: 117.2268,
        photo:
            'https://images.unsplash.com/photo-1581094480465-4e6c25fb4a52?auto=format&fit=crop&w=520&q=80',
        notes: 'Amankan panel dan lakukan draining area.',
        date: now.subtract(const Duration(days: 22)),
        pelapor: 'Eko Prasetyo',
        pja: 'Rudi Hartono',
        kategori: 'Kondisi Tidak Aman (KTA)',
      ),
    ];

    _hazardMapCtrl
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'HazardBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          try {
            final data = jsonDecode(msg.message);
            final action = data['action']?.toString();
            final id = data['id'] is int
                ? data['id'] as int
                : int.tryParse(data['id']?.toString() ?? '0') ?? 0;
            final hazard = _unclosedHazards.firstWhere(
              (h) => h.id == id,
              orElse: () => _unclosedHazards.first,
            );
            if (action == 'detail') {
              _showHazardDetailModal(context, hazard);
            } else if (action == 'close') {
              _showHazardCloseModal(context, hazard);
            }
          } catch (e) {
            debugPrint('Error on dashboard hazard bridge: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _injectCurrentPosition(_hazardMapCtrl),
        ),
      )
      ..loadHtmlString(_hazardMapHtml(
        mapMode: _hazardMapMode,
        userPosition: _lastUserPosition,
      ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _searchList.addAll({
          for (var row in _rawData.toList()) row.title.replaceAll('\n', ' ')
        }.toList());
      });
      _fetchHomeBanners();
      _fetchNotifCount();
      _initLocationAndProximity();
      _fetchHazardPointsFromApi();
    });
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _fetchHazardPointsFromApi([Position? pos]) async {
    try {
      final res = await _api.getSafeMapHazardPoints(
        days: 30,
        onlyOpen: true,
        lat: pos?.latitude ?? _lastUserPosition?.latitude,
        lon: pos?.longitude ?? _lastUserPosition?.longitude,
      );

      res.fold(
        (err) => debugPrint('Fetch safe map error: $err'),
        (points) {
          if (points.isNotEmpty && mounted) {
            final now = DateTime.now();
            final items = points.map((p) {
              final level = p['resiko']?.toString() ??
                  p['tingkatResiko']?.toString() ??
                  'Sedang';
              final color = (level == 'Kritis' || level == 'Ekstrem')
                  ? '#b91c1c'
                  : level == 'Tinggi'
                      ? '#dc2626'
                      : level == 'Sedang'
                          ? '#f59e0b'
                          : '#10b981';

              DateTime tgl = now;
              try {
                if (p['tanggal'] != null) {
                  tgl = DateTime.tryParse(p['tanggal'].toString()) ?? now;
                }
              } catch (_) {}

              return MapHazardItem(
                id: int.tryParse(p['id']?.toString() ?? '0') ?? 0,
                title: p['detail']?.toString() ??
                    p['temuan']?.toString() ??
                    'Temuan Hazard',
                area: p['area']?.toString() ?? 'Area Operasional',
                level: level,
                color: color,
                status: p['status']?.toString() ?? 'Open',
                statusColor: '#ef4444',
                lat: double.tryParse(p['lat']?.toString() ?? '0') ?? 0.0,
                lng: double.tryParse(p['lon']?.toString() ??
                        p['lng']?.toString() ??
                        '0') ??
                    0.0,
                photo: () {
                  final raw = p['photoUrl']?.toString() ??
                      p['fotoTemuan']?.toString() ??
                      '';
                  if (raw.isEmpty) {
                    return 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=520&q=80';
                  }
                  return raw.startsWith('http') ? raw : '${_api.baseUrl}$raw';
                }(),
                notes: p['tindakanPerbaikan']?.toString() ??
                    p['perbaikan']?.toString() ??
                    'Perlu tindakan isolasi dan perbaikan.',
                date: tgl,
                pelapor: p['nama']?.toString() ?? 'Pelapor Lapangan',
                pja: p['pja']?.toString() ?? 'Foreman Area',
                kategori: p['kategoriBahaya']?.toString() ??
                    'Kondisi Tidak Aman (KTA)',
              );
            }).toList();

            setState(() {
              _unclosedHazards = items;
            });
            _reloadMap();
          }
        },
      );
    } catch (e) {
      debugPrint('Error _fetchHazardPointsFromApi: $e');
    }
  }

  Future<void> _initLocationAndProximity() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _onUserPositionUpdated(pos);

      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2,
        ),
      ).listen((pos) {
        _onUserPositionUpdated(pos);
      });
    } catch (e) {
      debugPrint('Gagal inisialisasi lokasi dan proximity: $e');
    }
  }

  void _onUserPositionUpdated(Position pos) {
    final isFirstLoc = _lastUserPosition == null;
    _lastUserPosition = pos;

    _hazardMapCtrl.runJavaScript(
      'if(window.setUserLocation) window.setUserLocation(${pos.latitude}, ${pos.longitude}, ${pos.accuracy});',
    );

    if (isFirstLoc) {
      _fetchHazardPointsFromApi(pos);
    }

    // Jika mode 'off', jangan lakukan deteksi radar dan jangan bergetar
    if (_hazardMapMode == 'off') return;

    // Deteksi radar proximity jarak <= 20 meter (Getar perangkat saat masuk area temuan)
    for (final hazard in _unclosedHazards) {
      if (hazard.status.toLowerCase() == 'closed') continue;
      final dist = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        hazard.lat,
        hazard.lng,
      );
      if (dist <= 20.0) {
        _triggerProximityAlert(hazard, dist);
        return;
      }
    }
  }

  void _triggerProximityAlert(MapHazardItem hazard, double dist) {
    if (_hazardMapMode == 'off') return;
    final now = DateTime.now();
    if (_lastAlertTime != null &&
        now.difference(_lastAlertTime!).inSeconds < 15 &&
        _nearbyAlertHazard?.id == hazard.id) {
      return;
    }
    _lastAlertTime = now;
    _nearbyAlertHazard = hazard;
    _nearbyDistance = dist;

    // Getar perangkat saat masuk radius bahaya 20m (Haptic Feedback)
    HapticFeedback.vibrate();
    Future.delayed(const Duration(milliseconds: 320), () {
      HapticFeedback.heavyImpact();
    });
  }

  void _setMapMode(String mode) {
    if (_hazardMapMode == mode) return;
    setState(() {
      _hazardMapMode = mode;
    });
    _hazardMapCtrl.runJavaScript(
      "if(window.setMapMode) window.setMapMode('$mode');",
    );
  }

  void _reloadMap() {
    _hazardMapCtrl.loadHtmlString(
      _hazardMapHtml(
        mapMode: _hazardMapMode,
        userPosition: _lastUserPosition,
      ),
    );
  }

  void _showHazardCloseModal(BuildContext context, MapHazardItem hazard) {
    final tindakanCtrl = TextEditingController(
      text: 'Temuan bahaya telah ditindaklanjuti dan diselesaikan di lapangan.',
    );
    File? fotoPerbaikan;
    final picker = ImagePicker();
    bool isSaving = false;
    String closeMode = 'self';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isPjaMode = closeMode == 'pja';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF059669), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Closing Temuan Hazard',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              hazard.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            hazard.level,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${hazard.area} • Periode: ${hazard.date.day}/${hazard.date.month}/${hazard.date.year}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => closeMode = 'self'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isPjaMode
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !isPjaMode
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFE2E8F0),
                                width: !isPjaMode ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  !isPjaMode
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: !isPjaMode
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF94A3B8),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Selesaikan Sendiri',
                                  style: TextStyle(
                                    color: Color(0xFF047857),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => closeMode = 'pja'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isPjaMode
                                  ? const Color(0xFFFFF7ED)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isPjaMode
                                    ? const Color(0xFFF97316)
                                    : const Color(0xFFE2E8F0),
                                width: isPjaMode ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isPjaMode
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: isPjaMode
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFF94A3B8),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Kirim ke PJA',
                                  style: TextStyle(
                                    color: Color(0xFFC2410C),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tindakanCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: isPjaMode
                          ? 'Catatan instruksi untuk PJA...'
                          : 'Uraikan tindakan perbaikan yang telah dilakukan...',
                      hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF059669), width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (fotoPerbaikan != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            fotoPerbaikan!,
                            height: 110,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: InkWell(
                            onTap: () =>
                                setModalState(() => fotoPerbaikan = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    InkWell(
                      onTap: () async {
                        final picked = await picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 85,
                        );
                        if (picked != null) {
                          setModalState(() => fotoPerbaikan = File(picked.path));
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.camera_alt_rounded,
                                color: Color(0xFF059669), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Ambil Foto Bukti Perbaikan (Opsional)',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPjaMode
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final text = tindakanCtrl.text.trim();
                              if (text.isEmpty) {
                                SnackBarMsg.danger(
                                  context,
                                  'Uraian tindakan perbaikan wajib diisi.',
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);

                              try {
                                if (hazard.id != 999) {
                                  await _api.closeHazardDirect(
                                    hazard.id,
                                    text,
                                    closeMode: closeMode,
                                    fotoPerbaikan: fotoPerbaikan,
                                  );
                                }
                              } catch (e) {
                                debugPrint('Closing api error: $e');
                              }

                              if (!mounted) return;
                              setModalState(() => isSaving = false);
                              Navigator.pop(ctx);

                              setState(() {
                                hazard.status = 'Closed';
                                _unclosedHazards
                                    .removeWhere((item) => item.id == hazard.id);
                                if (_nearbyAlertHazard?.id == hazard.id) {
                                  _nearbyAlertHazard = null;
                                }
                              });

                              _reloadMap();
                              HapticFeedback.mediumImpact();
                              SnackBarMsg.success(
                                context,
                                'Temuan "${hazard.title}" berhasil di-close!',
                              );
                            },
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                      label: Text(
                        isSaving ? 'Menyimpan...' : 'Simpan & Close Hazard',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showHazardDetailModal(BuildContext context, MapHazardItem hazard) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FutureBuilder<Either<Map, Map<String, dynamic>>>(
        future: _api.getHazardDetailById(hazard.id),
        builder: (fCtx, snapshot) {
          Map<String, dynamic>? extra;
          if (snapshot.hasData) {
            snapshot.data!.fold((_) {}, (map) => extra = map);
          }

          final title = extra?['detail']?.toString() ??
              extra?['temuan']?.toString() ??
              hazard.title;
          final area = extra?['area']?.toString() ?? hazard.area;
          final detilLokasi = extra?['detilLokasi']?.toString() ??
              extra?['lokasi']?.toString() ??
              '';
          final kategori = extra?['kategoriBahaya']?.toString() ??
              extra?['kategori']?.toString() ??
              hazard.kategori;
          final jenis = extra?['jenisBahaya']?.toString() ?? '';
          final pelapor = extra?['nama']?.toString() ??
              extra?['pelapor']?.toString() ??
              hazard.pelapor;
          final nikPelapor = extra?['nik']?.toString() ?? '';
          final pja = extra?['pja']?.toString() ?? hazard.pja;
          final nikPja = extra?['nikPja']?.toString() ?? '';
          final perbaikan = extra?['tindakanPerbaikan']?.toString() ??
              extra?['perbaikan']?.toString() ??
              hazard.notes;
          final rawPhoto = extra?['photoUrl']?.toString() ??
              extra?['fotoTemuan']?.toString() ??
              hazard.photo;
          final photoUrl = rawPhoto.startsWith('/')
              ? '${_api.baseUrl}$rawPhoto'
              : rawPhoto;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      photoUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 110,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: Color(0xFF94A3B8), size: 36),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Color(int.parse(
                                  hazard.color.replaceFirst('#', '0xFF')))
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Color(int.parse(
                                  hazard.color.replaceFirst('#', '0xFF')))),
                        ),
                        child: Text(
                          hazard.level,
                          style: TextStyle(
                            color: Color(int.parse(
                                hazard.color.replaceFirst('#', '0xFF'))),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          hazard.status.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (hazard.id > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            '#${hazard.id}',
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        '${hazard.date.day}/${hazard.date.month}/${hazard.date.year}',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Area:',
                            '$area${detilLokasi.isNotEmpty ? ' ($detilLokasi)' : ''}'),
                        const Divider(height: 14, color: Color(0xFFE2E8F0)),
                        _buildDetailRow('Kategori:',
                            '$kategori${jenis.isNotEmpty ? ' • $jenis' : ''}'),
                        const Divider(height: 14, color: Color(0xFFE2E8F0)),
                        _buildDetailRow('Pelapor:',
                            '$pelapor${nikPelapor.isNotEmpty ? ' ($nikPelapor)' : ''}'),
                        const Divider(height: 14, color: Color(0xFFE2E8F0)),
                        _buildDetailRow('PJA:',
                            '$pja${nikPja.isNotEmpty ? ' ($nikPja)' : ''}'),
                        const Divider(height: 14, color: Color(0xFFE2E8F0)),
                        _buildDetailRow('Tindakan / Catatan:', perbaikan),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showHazardCloseModal(context, hazard);
                          },
                          icon:
                              const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Closing Hazard Ini'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HazardHubPage()),
                          );
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Hazard Hub'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1D4ED8),
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 11, horizontal: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  String _formatName(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    return text.trim().split(RegExp(r'\s+')).map((part) {
      if (part.contains('/')) {
        return part.split('/').map((sub) {
          if (sub.isEmpty) return '';
          return sub[0].toUpperCase() + sub.substring(1).toLowerCase();
        }).join('/');
      }
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join(' ');
  }

  String _formatCompany(String? text) {
    if (text == null || text.trim().isEmpty) return 'PT Indexim Coalindo';
    final trimmed = text.trim();
    if (trimmed.toUpperCase().startsWith('PT ')) {
      return 'PT ' + _formatName(trimmed.substring(3));
    }
    return _formatName(trimmed);
  }

  bool _matchesSearch(LinkMenuModel item, String query) {
    final title = item.title.replaceAll('\n', ' ').toLowerCase();
    final q = query.toLowerCase().trim();
    if (title.contains(q)) return true;

    // Smart semantic synonyms
    if (q.contains('bahaya') || q.contains('hazard') || q.contains('temuan')) {
      return item.route.contains('hazard');
    }
    if (q.contains('inspeksi') || q.contains('periksa') || q.contains('cek')) {
      return item.route.contains('inspection');
    }
    if (q.contains('mobil') || q.contains('kendaraan') || q.contains('unit') || q.contains('truk') || q.contains('p2h')) {
      return item.route.contains('p2h');
    }
    if (q.contains('roster') || q.contains('shift') || q.contains('jadwal')) {
      return item.route.contains('roster');
    }
    if (q.contains('p5m') || q.contains('sehat') || q.contains('fit')) {
      return item.route.contains('p5m');
    }
    if (q.contains('peringkat') || q.contains('skor') || q.contains('league') || q.contains('poin')) {
      return item.route.contains('league') || item.route.contains('achievement');
    }
    if (q.contains('insiden') || q.contains('kecelakaan') || q.contains('berita')) {
      return item.route.contains('incident') || item.route.contains('information');
    }
    if (q.contains('bbs') || q.contains('perilaku') || q.contains('behavior')) {
      return item.route.contains('bbs');
    }
    if (q.contains('ci') || q.contains('kondisi') || q.contains('condition')) {
      return item.route.contains('ci_assessment');
    }
    if (q.contains('coaching') || q.contains('bimbingan')) {
      return item.route.contains('coaching');
    }
    if (q.contains('observasi') || q.contains('observation')) {
      return item.route.contains('observation');
    }
    if (q.contains('safety talk') || q.contains('talk') || q.contains('briefing')) {
      return item.route.contains('safety_talk');
    }
    return false;
  }

  ({String name, Color color}) _getCategoryForMenu(LinkMenuModel menu) {
    if (listMenuSap.contains(menu)) {
      return (name: 'Modul SAP', color: const Color(0xFF1D4ED8));
    } else if (listMenuOhs1.contains(menu)) {
      return (name: 'Modul OHS', color: const Color(0xFF0F9F8F));
    } else {
      return (name: 'Performance Hub', color: const Color(0xFFF08A00));
    }
  }

  Future<void> _fetchHomeBanners() async {
    try {
      final res = await _api.getHomeBanners(limit: 5);
      if (!mounted) return;
      res.fold(
        (_) {
          if (mounted) {
            setState(() {
              _isLoadingBanners = false;
            });
          }
        },
        (banners) {
          if (mounted) {
            _cachedBanners = banners;
            setState(() {
              _homeBanners = banners;
              _isLoadingBanners = false;
            });
            _startBannerTimer();
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingBanners = false;
        });
      }
    }
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    if (_homeBanners.length <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final next = (_currentBannerIndex + 1) % _homeBanners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _fetchNotifCount() async {
    try {
      final counts = await _api.getNotificationCounts();
      if (mounted) {
        setState(() {
          _notifCount = counts['total'] ?? counts['unread'] ?? PreferenceService.getNotif();
        });
      }
    } catch (_) {}
  }

  Widget _buildHomeBannerSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 15),
      child: Container(
        height: 148,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 90,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const Spacer(),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 220,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 140,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultSafetyBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 15),
      child: Container(
        height: 148,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'SAFETY ALERT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Utamakan Keselamatan Dalam Bekerja',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'PT Indexim Coalindo • HSE Department',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeBannerSection() {
    if (_isLoadingBanners && _homeBanners.isEmpty) {
      return _buildHomeBannerSkeleton();
    }

    if (_homeBanners.isEmpty) {
      return _buildDefaultSafetyBanner();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 15),
      child: Column(
        children: [
          Container(
            height: 148,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: PageView.builder(
                controller: _bannerController,
                itemCount: _homeBanners.length,
                onPageChanged: (idx) {
                  setState(() => _currentBannerIndex = idx);
                },
                itemBuilder: (context, index) {
                  final banner = _homeBanners[index];
                  return _buildBannerSlide(banner);
                },
              ),
            ),
          ),
          if (_homeBanners.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_homeBanners.length, (idx) {
                final isCurrent = idx == _currentBannerIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isCurrent ? 20 : 6,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBannerSlide(IncidentNewsModel banner) {
    Color catColor = const Color(0xFFEF4444);
    final cat = banner.kategori.toLowerCase();
    if (cat.contains('banner') || cat.contains('informasi')) {
      catColor = const Color(0xFF0284C7);
    } else if (cat.contains('near miss')) {
      catColor = const Color(0xFFD97706);
    } else if (cat.contains('property')) {
      catColor = const Color(0xFFEA580C);
    } else if (cat.contains('first aid')) {
      catColor = const Color(0xFF0D9488);
    } else if (cat.contains('fire') || cat.contains('kebakaran')) {
      catColor = const Color(0xFFDC2626);
    } else if (cat.contains('fatal')) {
      catColor = const Color(0xFF991B1B);
    } else if (cat.contains('medical')) {
      catColor = const Color(0xFF7C3AED);
    }

    final hasImage = banner.gambarUrl != null && banner.gambarUrl!.isNotEmpty;
    final imgUrl = hasImage
        ? (banner.gambarUrl!.startsWith('http')
            ? banner.gambarUrl!
            : '${_api.baseUrl}${banner.gambarUrl}')
        : null;

    return Material(
      color: const Color(0xFF0F172A),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SafetyUpdatesPage()),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imgUrl != null)
              Image.network(
                imgUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildBannerFallbackBg(catColor),
              )
            else
              _buildBannerFallbackBg(catColor),

            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const [0.2, 1.0],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: catColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: catColor.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (cat.contains('banner') || cat.contains('informasi'))
                                  ? Icons.campaign_rounded
                                  : Icons.warning_amber_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              banner.kategori.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_homeBanners.isNotEmpty && banner.id == _homeBanners.first.id) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department_rounded, size: 11, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                'TERBARU',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_forward_rounded, size: 11, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'Lihat Detail',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.judul,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        banner.lokasi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 11,
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
    );
  }

  Widget _buildBannerFallbackBg(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.85),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.shield_outlined,
          size: 64,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Widget _buildProfessionalSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GlobalSearchPage()),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF2563EB),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cari modul, inspeksi, hazard, p2h...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 12, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'Cari',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Hai, ',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _formatName(_profile?.namaLengkap ?? 'Karyawan'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border:
                                          Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      _formatName(_profile?.posisi ?? 'Staff'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _formatCompany(_profile?.company),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _HomeNotificationButton(
                          count: _notifCount,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const NotifPage()),
                            );
                            _fetchNotifCount();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildProfessionalSearchBar(),
                  ],
                ),
              ),
              _buildHomeBannerSection(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _HomeModuleCard(
                      title: 'SAP',
                      imagePath: 'assets/images/home-sap.png',
                      labelColor: const Color(0xFF174B83),
                      iconHeight: 70,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (context) => const SapPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HomeModuleCard(
                      title: 'OHS',
                      imagePath: 'assets/images/home-ohs.png',
                      labelColor: const Color(0xFF0F9F8F),
                      iconHeight: 72,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (context) => const OhsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HomeModuleCard(
                      title: 'PERFORMANCE\nHUB',
                      imagePath: 'assets/images/home-performance-hub.png',
                      labelColor: const Color(0xFFF08A00),
                      iconHeight: 66,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (context) => const ExtraPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                            Row(
                              children: [
                                const Text(
                                  'Heatmap Lokasi Bahaya',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    '${_unclosedHazards.length} Titik',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hazard belum close (30 hari terakhir)',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Tombol Mode Simpel: Heatmap | Titik | Off
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDashboardModeButton('heatmap', 'Heatmap'),
                            _buildDashboardModeButton('points', 'Titik'),
                            _buildDashboardModeButton('off', 'Off'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 320,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: WebViewWidget(
                              controller: _hazardMapCtrl,
                              gestureRecognizers: {
                                Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer(),
                                ),
                              },
                            ),
                          ),
                          // Tombol Kontrol Peta Rapi (Fullscreen + Lokasi Saya)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Material(
                                  color: Colors.white,
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          fullscreenDialog: true,
                                          builder: (context) =>
                                              _FullscreenHazardMapPage(
                                            html: _hazardMapHtml(
                                              mapMode: _hazardMapMode,
                                              userPosition: _lastUserPosition,
                                            ),
                                            initialMode: _hazardMapMode,
                                            onModeChanged: (mode) {
                                              _setMapMode(mode);
                                            },
                                            onCloseHazard: (modalCtx, id) {
                                              final h = _unclosedHazards.firstWhere(
                                                (item) => item.id == id,
                                                orElse: () =>
                                                    _unclosedHazards.first,
                                              );
                                              _showHazardCloseModal(modalCtx, h);
                                            },
                                            onShowDetail: (modalCtx, id) {
                                              final h = _unclosedHazards.firstWhere(
                                                (item) => item.id == id,
                                                orElse: () =>
                                                    _unclosedHazards.first,
                                              );
                                              _showHazardDetailModal(modalCtx, h);
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Icon(
                                        Icons.fullscreen_rounded,
                                        color: Color(0xFF1D4ED8),
                                        size: 25,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Material(
                                  color: Colors.white,
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: () {
                                      _hazardMapCtrl.runJavaScript(
                                        'if(window.locateMe) window.locateMe();',
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Icon(
                                        Icons.my_location_rounded,
                                        color: Color(0xFF1D4ED8),
                                        size: 21,
                                      ),
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
                ],
              ),
            ),
            const SizedBox(height: 75),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDashboardModeButton(String key, String label) {
    final isSelected = _hazardMapMode == key;
    final isOff = key == 'off';
    return InkWell(
      onTap: () => _setMapMode(key),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isOff ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8))
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  String _hazardMapHtml({String mapMode = 'heatmap', Position? userPosition}) {
    final pos = userPosition ?? _lastUserPosition;
    final hasUserPos = pos != null;
    final userLat = pos?.latitude ?? 1.2057;
    final userLng = pos?.longitude ?? 117.2247;
    final userAccuracy = pos?.accuracy ?? 10.0;
    final pointsJson =
        jsonEncode(_unclosedHazards.map((e) => e.toJson()).toList());

    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <style>
        html, body, #map {
          height: 100%;
          width: 100%;
          margin: 0;
          padding: 0;
          overflow: hidden;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        /* Hilangkan tulisan tiles @ Esri attribution */
        .leaflet-control-attribution {
          display: none !important;
        }
        /* Hilangkan tombol zoom in / out (+ / -) */
        .leaflet-control-zoom {
          display: none !important;
        }
        .leaflet-popup-content-wrapper {
          border-radius: 14px;
          box-shadow: 0 12px 30px rgba(15, 23, 42, .22);
          padding: 4px;
        }
        .leaflet-popup {
          transition: opacity .14s ease-out;
        }
        .hazard-popup {
          width: 200px;
          padding: 2px;
        }
        .hazard-popup img {
          width: 100%;
          height: 96px;
          object-fit: cover;
          border-radius: 9px;
          display: block;
          margin-bottom: 8px;
        }
        .hazard-popup h3 {
          font-size: 13.5px;
          line-height: 1.25;
          margin: 0 0 5px;
          color: #111827;
          font-weight: 700;
        }
        .hazard-popup p {
          font-size: 11.5px;
          line-height: 1.35;
          margin: 3px 0;
          color: #4b5563;
        }
        .badge {
          display: inline-block;
          padding: 2px 7px;
          border-radius: 999px;
          color: white;
          font-size: 10px;
          font-weight: 700;
        }
        .btn-action-detail {
          width: 100%;
          padding: 7px 0;
          background: #1d4ed8;
          color: #ffffff;
          border: none;
          border-radius: 8px;
          font-size: 11.5px;
          font-weight: 700;
          cursor: pointer;
          margin-top: 8px;
        }
        .btn-action-close {
          width: 100%;
          padding: 7px 0;
          background: #059669;
          color: #ffffff;
          border: none;
          border-radius: 8px;
          font-size: 11.5px;
          font-weight: 700;
          cursor: pointer;
          margin-top: 5px;
        }
        .legend {
          background: rgba(255,255,255,.95);
          padding: 8px 10px;
          border-radius: 12px;
          box-shadow: 0 8px 20px rgba(15, 23, 42, .14);
          font-size: 11px;
          color: #1f2937;
        }
        .legend-row {
          display: flex;
          align-items: center;
          gap: 6px;
          margin-top: 4px;
        }
        .dot {
          width: 9px;
          height: 9px;
          border-radius: 50%;
          display: inline-block;
        }
        .user-location-arrow {
          width: 34px;
          height: 34px;
          display: flex;
          align-items: center;
          justify-content: center;
          border-radius: 50%;
          background: #ffffff;
          border: 2px solid #2563eb;
          box-shadow: 0 0 0 7px rgba(37, 99, 235, .18), 0 4px 12px rgba(15, 23, 42, .28);
          position: relative;
        }
        .user-location-arrow svg {
          width: 24px;
          height: 24px;
          fill: #2563eb;
          transform: rotate(18deg);
        }
        .user-location-arrow::after {
          content: '';
          position: absolute; 
          inset: -9px;
          border: 2px solid rgba(37, 99, 235, .45);
          border-radius: 50%;
          animation: userPulse 1.8s ease-out infinite;
        }
        @keyframes userPulse {
          0% { transform: scale(.65); opacity: 1; }
          100% { transform: scale(1.7); opacity: 0; }
        }
        .hazard-pin-wrap {
          position: relative;
          width: 32px;
          height: 32px;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
        }
        .hazard-ping {
          position: absolute;
          width: 14px;
          height: 14px;
          border-radius: 50%;
          animation: hazardPing 1.9s cubic-bezier(0, 0, 0.2, 1) infinite;
          opacity: 0.85;
        }
        @keyframes hazardPing {
          70%, 100% {
            transform: scale(2.8);
            opacity: 0;
          }
        }
        .hazard-pin-badge {
          width: 24px;
          height: 24px;
          border-radius: 50% 50% 50% 0;
          transform: rotate(-45deg);
          border: 2px solid #ffffff;
          box-shadow: 0 4px 12px rgba(0,0,0,0.6);
          display: flex;
          align-items: center;
          justify-content: center;
          position: relative;
          z-index: 2;
        }
        .hazard-pin-badge span {
          transform: rotate(45deg);
          color: #ffffff;
          font-size: 13px;
          font-weight: 900;
          line-height: 1;
        }
      </style>
    </head>
    <body>
      <div id="map"></div>
      <script>
        // Mode Satelit langsung, tanpa attribution
        const satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
          maxZoom: 19,
          keepBuffer: 4,
          updateWhenIdle: false,
          attribution: ''
        });

        const hasUserPos = $hasUserPos;
        const initialUserLat = $userLat;
        const initialUserLng = $userLng;
        const initialAccuracy = $userAccuracy;

        // Inisialisasi map langsung ke lokasi pengguna jika tersedia agar area sekitarnya langsung terlihat
        const map = L.map('map', {
          center: hasUserPos ? [initialUserLat, initialUserLng] : [1.2057, 117.2247],
          zoom: hasUserPos ? 17 : 13,
          layers: [satellite],
          preferCanvas: true,
          zoomControl: false,
          attributionControl: false,
          dragging: true,
          scrollWheelZoom: true,
          doubleClickZoom: true,
          touchZoom: true,
          closePopupOnClick: true,
          zoomAnimation: true,
          fadeAnimation: true,
          markerZoomAnimation: true,
          inertia: true,
          inertiaDeceleration: 2600,
          easeLinearity: .22,
          zoomSnap: .5,
          zoomDelta: .5,
          wheelPxPerZoomLevel: 90
        });

        if (map.attributionControl) {
          map.attributionControl.setPrefix(false);
        }

        map.on('preclick', function() {
          map.closePopup();
        });

        const hazardPoints = $pointsJson;

        const heatLayer = L.layerGroup();
        const markerLayer = L.layerGroup();

        if ('$mapMode' === 'heatmap') {
          heatLayer.addTo(map);
          markerLayer.addTo(map);
        } else if ('$mapMode' === 'points') {
          markerLayer.addTo(map);
        }

        window.setMapMode = function(mode) {
          if (mode === 'heatmap') {
            if (!map.hasLayer(heatLayer)) map.addLayer(heatLayer);
            if (!map.hasLayer(markerLayer)) map.addLayer(markerLayer);
          } else if (mode === 'points') {
            if (map.hasLayer(heatLayer)) map.removeLayer(heatLayer);
            if (!map.hasLayer(markerLayer)) map.addLayer(markerLayer);
          } else if (mode === 'off') {
            if (map.hasLayer(heatLayer)) map.removeLayer(heatLayer);
            if (map.hasLayer(markerLayer)) map.removeLayer(markerLayer);
          }
        };

        window.toggleHeatmap = function(active) {
          window.setMapMode(active ? 'heatmap' : 'points');
        };

        let userMarker = null;
        let userAccuracyCircle = null;
        let userCoordinates = hasUserPos ? [initialUserLat, initialUserLng] : null;

        function renderUserMarker(lat, lng, accuracy, autoFly) {
          userCoordinates = [lat, lng];
          if (userMarker) map.removeLayer(userMarker);
          if (userAccuracyCircle) map.removeLayer(userAccuracyCircle);

          const userIcon = L.divIcon({
            className: '',
            html: '<div class="user-location-arrow"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2 4.5 20.29l.71.71L12 18l6.79 3 .71-.71L12 2z"/></svg></div>',
            iconSize: [38, 38],
            iconAnchor: [19, 19]
          });
          userAccuracyCircle = L.circle(userCoordinates, {
            radius: Math.max(accuracy || 10, 10),
            color: '#2563eb',
            weight: 1,
            fillColor: '#60a5fa',
            fillOpacity: .12
          }).addTo(map);
          userMarker = L.marker(userCoordinates, {
            icon: userIcon,
            zIndexOffset: 1000
          }).addTo(map);
          userMarker.bindPopup(`
            <div style="min-width:170px">
              <strong style="font-size:13px;color:#1d4ed8">Posisi Saya</strong>
              <p style="margin:5px 0 2px;font-size:11px;color:#4b5563">Lokasi perangkat saat ini</p>
              <p style="margin:2px 0;font-size:10.5px;color:#64748b">\${lat.toFixed(6)}, \${lng.toFixed(6)}</p>
              <p style="margin:2px 0;font-size:10.5px;color:#64748b">Akurasi ±\${Math.round(accuracy || 0)} meter</p>
            </div>
          `);

          if (autoFly) {
            map.setView(userCoordinates, 17);
          }
        }

        if (hasUserPos) {
          renderUserMarker(initialUserLat, initialUserLng, initialAccuracy, true);
        }

        window.setUserLocation = function(lat, lng, accuracy) {
          renderUserMarker(lat, lng, accuracy, true);
        };

        window.locateMe = function() {
          if (userCoordinates) {
            map.flyTo(userCoordinates, 17, { animate: true, duration: .55 });
            if (userMarker) setTimeout(() => userMarker.openPopup(), 600);
          }
        };

        hazardPoints.forEach((point) => {
          // Area temuan bahaya dibuat 20 meter (sesuai spesifikasi)
          L.circle([point.lat, point.lng], {
            radius: 20,
            color: point.color,
            weight: 1.5,
            fillColor: point.color,
            fillOpacity: 0.35
          }).addTo(heatLayer);

          // Titik Hazard Pin yang Jelas & Terlihat
          const pinIcon = L.divIcon({
            className: '',
            html: `
              <div class="hazard-pin-wrap">
                <div class="hazard-ping" style="background:\${point.color}"></div>
                <div class="hazard-pin-badge" style="background:\${point.color}">
                  <span>!</span>
                </div>
              </div>
            `,
            iconSize: [30, 30],
            iconAnchor: [15, 30],
            popupAnchor: [0, -30]
          });

          const marker = L.marker([point.lat, point.lng], {
            icon: pinIcon,
            zIndexOffset: 300
          }).addTo(markerLayer);

          marker.bindPopup(`
            <div class="hazard-popup">
              <img src="\${point.photo}" onerror="this.style.display='none'" />
              <div style="display:flex;gap:4px;margin-bottom:6px">
                <span class="badge" style="background:\${point.color}">\${point.level}</span>
                <span class="badge" style="background:\${point.statusColor}">\${point.status}</span>
              </div>
              <h3>\${point.title}</h3>
              <p><strong>Area:</strong> \${point.area}</p>
              <p><strong>Periode:</strong> \${point.date}</p>
              <p style="margin-top:4px">\${point.notes}</p>
              <button class="btn-action-detail" onclick="if(window.HazardBridge) window.HazardBridge.postMessage(JSON.stringify({action:'detail',id:\${point.id}}))">
                🔍 Lihat Detail
              </button>
              <button class="btn-action-close" onclick="if(window.HazardBridge) window.HazardBridge.postMessage(JSON.stringify({action:'close',id:\${point.id}}))">
                ⚡ Closing Hazard
              </button>
            </div>
          `, {
            maxWidth: 220,
            autoPan: true,
            autoPanPaddingTopLeft: [18, 90],
            autoPanPaddingBottomRight: [18, 28]
          });
        });

        // Fit bounds HANYA jika posisi user belum tersedia
        if (!hasUserPos && !userCoordinates && hazardPoints.length > 0) {
          const validCoords = hazardPoints
            .filter(p => p.lat && p.lng && (Math.abs(p.lat) > 0.001 || Math.abs(p.lng) > 0.001))
            .map(p => [p.lat, p.lng]);
          if (validCoords.length > 0) {
            const bounds = L.latLngBounds(validCoords);
            map.fitBounds(bounds, { padding: [30, 30], maxZoom: 15 });
          }
        }

        const legend = L.control({ position: 'bottomleft' });
        legend.onAdd = function () {
          const div = L.DomUtil.create('div', 'legend');
          div.innerHTML = `
            <strong>Level Hazard (30 Hari)</strong>
            <div class="legend-row"><span class="dot" style="background:#22c55e"></span>Rendah</div>
            <div class="legend-row"><span class="dot" style="background:#f59e0b"></span>Sedang</div>
            <div class="legend-row"><span class="dot" style="background:#ef4444"></span>Tinggi</div>
            <div class="legend-row"><span class="dot" style="background:#b91c1c"></span>Kritis</div>
          `;
          return div;
        };
        legend.addTo(map);

        setTimeout(() => map.invalidateSize(), 250);
      </script>
    </body>
    </html>
    ''';
  }
}

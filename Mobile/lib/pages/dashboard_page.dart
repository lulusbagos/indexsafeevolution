import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../models/incident_news_model.dart';
import '../models/link_model.dart';
import '../services/api.dart';
import '../services/database.dart';
import '../services/notification.dart';
import '../services/preference.dart';
import '../utils/links.dart';
import '../widgets/snackbar_msg.dart';
import 'approval/approval_center_page.dart';
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
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
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

  factory MapHazardItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    try {
      if (json['date'] != null) {
        final dStr = json['date'].toString();
        if (dStr.contains('/')) {
          final parts = dStr.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]) ?? 1;
            final month = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[2]) ?? DateTime.now().year;
            parsedDate = DateTime(year, month, day);
          }
        } else {
          parsedDate = DateTime.tryParse(dStr) ?? DateTime.now();
        }
      }
    } catch (_) {}

    return MapHazardItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? 'Temuan Hazard',
      area: json['area']?.toString() ?? 'Area Tambang',
      level: json['level']?.toString() ?? 'Sedang',
      color: json['color']?.toString() ?? '#f59e0b',
      status: json['status']?.toString() ?? 'Open',
      statusColor: json['statusColor']?.toString() ?? '#ef4444',
      lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lng: (json['lng'] is num) ? (json['lng'] as num).toDouble() : double.tryParse(json['lng']?.toString() ?? '0') ?? 0.0,
      photo: json['photo']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      date: parsedDate,
      pelapor: json['pelapor']?.toString() ?? 'Safety Officer',
      pja: json['pja']?.toString() ?? 'Supervisor Lapangan',
      kategori: json['kategori']?.toString() ?? 'Kondisi Tidak Aman (KTA)',
    );
  }
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

Widget buildSafeMapWebView(WebViewController controller) {
  PlatformWebViewWidgetCreationParams params =
      PlatformWebViewWidgetCreationParams(
    controller: controller.platform,
    layoutDirection: TextDirection.ltr,
    gestureRecognizers: {
      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
    },
  );

  if (WebViewPlatform.instance is AndroidWebViewPlatform) {
    params = AndroidWebViewWidgetCreationParams
        .fromPlatformWebViewWidgetCreationParams(
      params,
      displayWithHybridComposition: true,
    );
  }

  return WebViewWidget.fromPlatformCreationParams(params: params);
}

class _FullscreenHazardMapPage extends StatefulWidget {
  const _FullscreenHazardMapPage({
    super.key,
    required this.html,
    required this.onCloseHazard,
    required this.onShowDetail,
    this.initialMode = 'heatmap',
    this.onModeChanged,
    this.unclosedHazards = const [],
    this.initialUserPosition,
  });

  final String html;
  final Function(BuildContext context, int id) onCloseHazard;
  final Function(BuildContext context, int id) onShowDetail;
  final String initialMode;
  final ValueChanged<String>? onModeChanged;
  final List<MapHazardItem> unclosedHazards;
  final Position? initialUserPosition;

  @override
  State<_FullscreenHazardMapPage> createState() =>
      _FullscreenHazardMapPageState();
}

class _FullscreenHazardMapPageState extends State<_FullscreenHazardMapPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _api = ApiService();
  late final WebViewController _controller;
  late String _mapMode;
  bool _isHunterMode = true;
  Position? _currentPos;
  StreamSubscription<Position>? _posSub;
  int _currentTargetIndex = 0;
  int _score = 350;
  bool _hasVibratedForTarget = false;

  late final AnimationController _pulseCtrl;
  late final AnimationController _radarRotateCtrl;

  late List<MapHazardItem> _liveHazards;
  Timer? _realtimeTimer;
  bool _isScanningRealtime = false;
  String _selectedFilter = 'all'; // 'all', '1km', 'high'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapMode = PreferenceService.getHazardMapMode();
    _currentPos = widget.initialUserPosition;
    _liveHazards = List<MapHazardItem>.from(widget.unclosedHazards);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _radarRotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

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
            } else if (action == 'select') {
              final sorted = _sortedHazards;
              final foundIdx = sorted.indexWhere((h) => h.id == id);
              if (foundIdx != -1) {
                setState(() {
                  _currentTargetIndex = foundIdx;
                  _hasVibratedForTarget = false;
                });
                _updateMapGuide();
              }
            }
          } catch (e) {
            debugPrint('Error handling HazardBridge message: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _injectCurrentPosition(_controller);
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) _updateMapGuide();
            });
          },
        ),
      )
      ..loadHtmlString(widget.html, baseUrl: 'https://unpkg.com');

    _startLocationStream();

    // Jalankan scan realtime di sekitar begitu masuk mode layar penuh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRealtimeNearbyHazards(silent: true);
    });

    _startRealtimeTimer();
  }

  void _startRealtimeTimer() {
    _realtimeTimer?.cancel();
    // Polling efisien hemat daya setiap 25 detik (dapat di-refresh manual via tombol PING)
    _realtimeTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted && _isHunterMode) {
        _fetchRealtimeNearbyHazards(silent: true);
      }
    });
  }

  void _stopRealtimeTimer() {
    _realtimeTimer?.cancel();
    _realtimeTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Hentikan timer dan animasi saat diminimize agar tidak menguras baterai dan tidak panas
      _stopRealtimeTimer();
      _posSub?.pause();
      _pulseCtrl.stop();
      _radarRotateCtrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      // Nyalakan kembali saat user kembali ke aplikasi
      _pulseCtrl.repeat(reverse: true);
      _radarRotateCtrl.repeat();
      _posSub?.resume();
      _startRealtimeTimer();
      _fetchRealtimeNearbyHazards(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRealtimeTimer();
    _posSub?.cancel();
    _pulseCtrl.dispose();
    _radarRotateCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRealtimeNearbyHazards({bool silent = true}) async {
    if (_isScanningRealtime) return;
    setState(() => _isScanningRealtime = true);
    if (!silent) HapticFeedback.selectionClick();

    try {
      final pos = _currentPos ?? widget.initialUserPosition;
      final res = await _api.getSafeMapHazardPoints(
        days: 30,
        onlyOpen: true,
        limit: 120, // Realtime hunter mode memuat hingga 120 hazard sekitar
        lat: pos?.latitude,
        lon: pos?.longitude,
      );

      res.fold(
        (err) => debugPrint('[HazardHunter] Realtime scan error: $err'),
        (points) {
          if (!mounted) return;
          final now = DateTime.now();
          final items = <MapHazardItem>[];

          for (final p in points) {
            final statusStr = p['status']?.toString() ?? 'Open';
            final statusLower = statusStr.toLowerCase();
            if (statusLower == 'closed' ||
                statusLower == 'selesai' ||
                statusLower == 'tutup') {
              continue;
            }

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
              if (p['tanggalIso'] != null) {
                tgl = DateTime.tryParse(p['tanggalIso'].toString()) ?? now;
              } else if (p['tanggal'] != null) {
                tgl = DateTime.tryParse(p['tanggal'].toString()) ?? now;
              }
            } catch (_) {}

            items.add(MapHazardItem(
              id: int.tryParse(p['id']?.toString() ?? '0') ?? 0,
              title: p['detail']?.toString() ??
                  p['temuan']?.toString() ??
                  'Temuan Hazard',
              area: p['area']?.toString() ?? 'Area Operasional',
              level: level,
              color: color,
              status: statusStr,
              statusColor: '#ef4444',
              lat: double.tryParse(p['lat']?.toString() ?? '0') ?? 0.0,
              lng: double.tryParse(
                      p['lon']?.toString() ?? p['lng']?.toString() ?? '0') ??
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
            ));
          }

          if (items.isNotEmpty) {
            setState(() {
              _liveHazards = items;
            });
            final jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
            _controller.runJavaScript(
              'if(window.renderHazardPoints) window.renderHazardPoints($jsonStr);',
            );
            _updateMapGuide();
            if (!silent) HapticFeedback.mediumImpact();
          }
        },
      );
    } catch (e) {
      debugPrint('[HazardHunter] Realtime scan exception: $e');
    } finally {
      if (mounted) setState(() => _isScanningRealtime = false);
    }
  }

  Future<void> _startLocationStream() async {
    try {
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (e) {
        debugPrint('Geolocator service check fallback: $e');
        serviceEnabled = true;
      }
      if (!serviceEnabled) return;

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
        ),
      ).listen(
        (pos) {
          if (mounted) {
            setState(() {
              _currentPos = pos;
            });
            _controller.runJavaScript(
              'if(window.setUserLocation) window.setUserLocation(${pos.latitude}, ${pos.longitude}, ${pos.accuracy});',
            );
            _updateMapGuide();
          }
        },
        onError: (err) {
          debugPrint('Position stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Location stream error: $e');
    }
  }

  void _updateMapGuide() {
    if (!_isHunterMode || _mapMode == 'off') {
      _controller
          .runJavaScript('if(window.clearGuideLine) window.clearGuideLine();');
      return;
    }
    final sorted = _sortedHazards;
    if (sorted.isEmpty) return;
    final target = sorted[_currentTargetIndex % sorted.length];
    final pos = _currentPos ?? widget.initialUserPosition;
    if (pos == null) return;

    _controller.runJavaScript(
      'if(window.updateGuideLine) window.updateGuideLine(${pos.latitude}, ${pos.longitude}, ${target.lat}, ${target.lng}, "${target.color}");',
    );
  }

  double _calculateBearing(
      double startLat, double startLng, double endLat, double endLng) {
    final dLng = (endLng - startLng) * (pi / 180.0);
    final phi1 = startLat * (pi / 180.0);
    final phi2 = endLat * (pi / 180.0);
    final y = sin(dLng) * cos(phi2);
    final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dLng);
    final rad = atan2(y, x);
    return (rad * (180.0 / pi) + 360.0) % 360.0;
  }

  String _bearingToDirectionName(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return 'Utara';
    if (bearing >= 22.5 && bearing < 67.5) return 'Timur Laut';
    if (bearing >= 67.5 && bearing < 112.5) return 'Timur';
    if (bearing >= 112.5 && bearing < 157.5) return 'Tenggara';
    if (bearing >= 157.5 && bearing < 202.5) return 'Selatan';
    if (bearing >= 202.5 && bearing < 247.5) return 'Barat Daya';
    if (bearing >= 247.5 && bearing < 292.5) return 'Barat';
    return 'Barat Laut';
  }

  List<MapHazardItem> get _filteredHazards {
    if (_liveHazards.isEmpty) return [];
    final pos = _currentPos ?? widget.initialUserPosition;
    return _liveHazards.where((h) {
      if (_selectedFilter == '1km' && pos != null) {
        final d = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, h.lat, h.lng);
        return d <= 1000.0;
      } else if (_selectedFilter == 'high') {
        final lvl = h.level.toLowerCase();
        return lvl == 'kritis' || lvl == 'tinggi' || lvl == 'ekstrem';
      }
      return true;
    }).toList();
  }

  List<MapHazardItem> get _sortedHazards {
    final list = List<MapHazardItem>.from(_filteredHazards);
    if (list.isEmpty) return [];
    final pos = _currentPos ?? widget.initialUserPosition;
    if (pos != null) {
      list.sort((a, b) {
        final da = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, a.lat, a.lng);
        final db = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, b.lat, b.lng);
        return da.compareTo(db);
      });
    }
    return list;
  }

  void _onSelectMode(String mode) {
    if (_mapMode == mode) return;
    setState(() => _mapMode = mode);
    PreferenceService.setHazardMapMode(mode);
    _controller.runJavaScript(
      "if(window.setMapMode) window.setMapMode('$mode');",
    );
    widget.onModeChanged?.call(mode);
    if (mode == 'off') {
      _hasVibratedForTarget = false;
      _controller
          .runJavaScript('if(window.clearGuideLine) window.clearGuideLine();');
    } else {
      _updateMapGuide();
    }
  }

  void _flyToTarget(MapHazardItem target) {
    _controller.runJavaScript(
      "map.flyTo([${target.lat}, ${target.lng}], 17.5, { animate: true, duration: 0.7 });",
    );
    _updateMapGuide();
  }

  void _showTooFarWarning(BuildContext context, double distance) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
        ),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded,
                color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text(
              'Belum Dalam Radius 50M',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jarak Anda saat ini: ${distance.round()} meter dari titik hazard.',
              style: const TextStyle(
                  color: Color(0xFFE2E8F0), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security_rounded, color: Colors.amber, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SOP K3: Hazard hanya dapat diamankan (takeup) jika berada dalam radius 50 meter untuk verifikasi fisik langsung di lapangan.',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Siap, Saya Dekati Target',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEncounterModal(
      BuildContext context, MapHazardItem target, double distance,
      {required bool canTakeUp}) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF090D16), Color(0xFF131B2E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
                color: canTakeUp
                    ? const Color(0xFF10B981)
                    : const Color(0xFF00E5FF),
                width: 1.8),
            boxShadow: [
              BoxShadow(
                color: (canTakeUp
                        ? const Color(0xFF10B981)
                        : const Color(0xFF00E5FF))
                    .withOpacity(0.45),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Title Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: canTakeUp
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFEF4444), const Color(0xFFF97316)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (canTakeUp ? Colors.green : Colors.red)
                          .withOpacity(0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        canTakeUp
                            ? Icons.check_circle_rounded
                            : Icons.radar_rounded,
                        color: Colors.white,
                        size: 18),
                    const SizedBox(width: 7),
                    Text(
                      canTakeUp
                          ? 'TARGET VERIFIKASI < 50M: AMANKAN!'
                          : 'WILD HAZARD TERDETEKSI!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Photo with Tactical Scan Reticle Overlay
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.black38,
                      child: Image.network(
                        target.photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1E293B),
                          child: const Icon(Icons.warning_amber_rounded,
                              size: 54, color: Colors.amber),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: canTakeUp
                              ? Colors.greenAccent
                              : const Color(0xFF00E5FF),
                          width: 2),
                    ),
                    child: Center(
                      child: Icon(Icons.filter_center_focus,
                          color: canTakeUp
                              ? Colors.greenAccent
                              : const Color(0xFF00E5FF),
                          size: 44),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        'ID #${target.id}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: canTakeUp
                                ? Colors.greenAccent
                                : Colors.amberAccent),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_fixed,
                              color: canTakeUp
                                  ? Colors.greenAccent
                                  : Colors.amberAccent,
                              size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Jarak: ${distance.round()}m ${canTakeUp ? "(Siap Amankan)" : "(Dekati)"}',
                            style: TextStyle(
                              color: canTakeUp
                                  ? Colors.greenAccent
                                  : Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                target.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: target.color.startsWith('#')
                          ? Color(
                              int.parse(target.color.replaceFirst('#', '0xFF')))
                          : Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      target.level.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      target.area,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // XP Reward Box
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF00E5FF).withOpacity(0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.military_tech_rounded,
                        color: Colors.amber, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Reward Hunter: +50 XP & Amankan Area Lapangan',
                      style: TextStyle(
                        color: Color(0xFFE0F2FE),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canTakeUp
                            ? const Color(0xFF10B981)
                            : const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: canTakeUp ? 6 : 0,
                        shadowColor: canTakeUp
                            ? const Color(0xFF10B981).withOpacity(0.6)
                            : null,
                      ),
                      onPressed: canTakeUp
                          ? () {
                              Navigator.pop(modalCtx);
                              setState(() {
                                _score += 50;
                              });
                              widget.onCloseHazard(context, target.id);
                            }
                          : () {
                              Navigator.pop(modalCtx);
                              _showTooFarWarning(context, distance);
                            },
                      icon: Icon(
                          canTakeUp
                              ? Icons.check_circle_rounded
                              : Icons.lock_rounded,
                          size: 18),
                      label: Text(
                        canTakeUp
                            ? 'Amankan & Close Temuan (+50P)'
                            : 'Terkunci (Harus < 50M)',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white12,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(modalCtx);
                      widget.onShowDetail(context, target.id);
                    },
                    icon: const Icon(Icons.info_outline_rounded,
                        color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImageZoomDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.black,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(40),
                          child: Icon(Icons.broken_image,
                              color: Colors.white54, size: 48),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedHazards;
    final hasTargets = sorted.isNotEmpty;
    final target =
        hasTargets ? sorted[_currentTargetIndex % sorted.length] : null;

    final userLat = _currentPos?.latitude ??
        widget.initialUserPosition?.latitude ??
        (hasTargets ? target!.lat + 0.0003 : 1.0564);
    final userLng = _currentPos?.longitude ??
        widget.initialUserPosition?.longitude ??
        (hasTargets ? target!.lng + 0.0002 : 117.7265);

    double distance = 999;
    double bearing = 0;
    String dirName = 'Utara';

    if (target != null) {
      distance =
          Geolocator.distanceBetween(userLat, userLng, target.lat, target.lng);
      bearing = _calculateBearing(userLat, userLng, target.lat, target.lng);
      dirName = _bearingToDirectionName(bearing);
    }

    final isWithin50Meters = distance <= 50.0;

    // Haptic saat masuk radius 50m
    if (isWithin50Meters && !_hasVibratedForTarget) {
      _hasVibratedForTarget = true;
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 250),
          () => HapticFeedback.heavyImpact());
    } else if (!isWithin50Meters && _hasVibratedForTarget) {
      _hasVibratedForTarget = false;
    }

    // Warna target border
    final targetColor = (target != null && target.color.startsWith('#'))
        ? Color(int.parse(target.color.replaceFirst('#', '0xFF')))
        : const Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Leaflet Satellite Map
          Positioned.fill(
            child: SafeArea(
              child: buildSafeMapWebView(_controller),
            ),
          ),

          // TOP HUD: Futuristic Obsidian Radar Deck
          Positioned(
            top: 10,
            left: 8,
            right: 8,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF070B14).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withOpacity(0.35),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.65),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.12),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Back Button
                    Material(
                      color: Colors.white.withOpacity(0.08),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(Icons.arrow_back_rounded,
                              color: Color(0xFF38BDF8), size: 19),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Rotating Radar Sweep Icon & Hunter Title
                    Expanded(
                      child: Row(
                        children: [
                          RotationTransition(
                            turns: _radarRotateCtrl,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF00E5FF).withOpacity(0.4),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: const Icon(Icons.radar_rounded,
                                  color: Color(0xFF00E5FF), size: 18),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'HAZARD HUNTER',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11.5,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        '${_score}P',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 8.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Row(
                                  children: [
                                    FadeTransition(
                                      opacity: _pulseCtrl,
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _isScanningRealtime
                                            ? 'MEMINDAI...'
                                            : 'REALTIME • ${sorted.length} TARGET',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF7DD3FC),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
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
                    const SizedBox(width: 4),

                    // Ping Radar Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _fetchRealtimeNearbyHazards(silent: false),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 5),
                          decoration: BoxDecoration(
                            color: _isScanningRealtime
                                ? const Color(0xFFF59E0B).withOpacity(0.2)
                                : const Color(0xFF00E5FF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isScanningRealtime
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF00E5FF).withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.wifi_tethering_rounded,
                                size: 13,
                                color: _isScanningRealtime
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF00E5FF),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _isScanningRealtime ? 'SCAN' : 'PING',
                                style: TextStyle(
                                  color: _isScanningRealtime
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF00E5FF),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Mode Switcher (Heatmap | Titik | Off)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFullscreenModeButton('heatmap', 'Heatmap'),
                          _buildFullscreenModeButton('points', 'Titik'),
                          _buildFullscreenModeButton('off', 'Off'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // TACTICAL QUICK FILTER BAR (Semua, Sekitar <1km, Risiko Tinggi)
          Positioned(
            top: 72,
            left: 12,
            right: 12,
            child: SafeArea(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'SEMUA (${_liveHazards.length})'),
                    const SizedBox(width: 6),
                    _buildFilterChip('1km', '📍 SEKITAR < 1KM'),
                    const SizedBox(width: 6),
                    _buildFilterChip('high', '🔥 RISIKO TINGGI / KRITIS'),
                  ],
                ),
              ),
            ),
          ),

          // FLOATING TACTICAL COMPASS / GUIDANCE HUD
          if (_isHunterMode && target != null && _mapMode != 'off')
            Positioned(
              top: 114,
              left: 14,
              right: 14,
              child: SafeArea(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070B14).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isWithin50Meters
                            ? const Color(0xFF10B981)
                            : const Color(0xFF00E5FF),
                        width: 1.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isWithin50Meters
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF00E5FF))
                              .withOpacity(0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Compass needle
                        AnimatedRotation(
                          turns: bearing / 360.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: isWithin50Meters
                                    ? [
                                        const Color(0xFF10B981),
                                        const Color(0xFF059669)
                                      ]
                                    : [
                                        const Color(0xFF0284C7),
                                        const Color(0xFF00E5FF)
                                      ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isWithin50Meters
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF00E5FF))
                                      .withOpacity(0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.navigation_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isWithin50Meters
                                  ? '🎯 RADIUS VERIFIKASI < 50M • SIAP DIAMANKAN!'
                                  : '🧭 IKUTI ARAH • TARGET #${(_currentTargetIndex % sorted.length) + 1}',
                              style: TextStyle(
                                color: isWithin50Meters
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFF7DD3FC),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              isWithin50Meters
                                  ? '${distance.round()} METER • SIAP CLOSING (+50P)'
                                  : '${distance.round()} METER • KE ${dirName.toUpperCase()}',
                              style: TextStyle(
                                color: isWithin50Meters
                                    ? const Color(0xFF4ADE80)
                                    : Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Floating GPS Tools on Right
          Positioned(
            bottom: (_isHunterMode && target != null) ? 220 : 24,
            right: 14,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Auto Lock Nearest Target Button
                  if (hasTargets)
                    Material(
                      color: const Color(0xFF070B14).withOpacity(0.9),
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _currentTargetIndex = 0;
                            _hasVibratedForTarget = false;
                          });
                          _flyToTarget(sorted[0]);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    const Color(0xFF00E5FF).withOpacity(0.4)),
                          ),
                          child: const Icon(
                            Icons.center_focus_strong_rounded,
                            color: Color(0xFF00E5FF),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Locate Me Button
                  Material(
                    color: const Color(0xFF070B14).withOpacity(0.9),
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _controller.runJavaScript(
                          'if(window.locateMe) window.locateMe();',
                        );
                        _updateMapGuide();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF38BDF8).withOpacity(0.4)),
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: Color(0xFF38BDF8),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM ENCOUNTER DECK (Futuristic Hazard Hunter Encounter Card)
          if (_isHunterMode && target != null && _mapMode != 'off')
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF070B14), Color(0xFF111A2D)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isWithin50Meters
                          ? const Color(0xFF10B981)
                          : targetColor.withOpacity(0.85),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isWithin50Meters
                                ? const Color(0xFF10B981)
                                : targetColor)
                            .withOpacity(0.35),
                        blurRadius: 22,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Target Index & Navigation Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF0284C7).withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFF00E5FF)),
                                ),
                                child: Text(
                                  '🎯 TARGET #${(_currentTargetIndex % sorted.length) + 1}/${sorted.length}${_currentTargetIndex == 0 ? ' (TERDEKAT)' : ''}',
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: targetColor.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: targetColor.withOpacity(0.8)),
                                ),
                                child: Text(
                                  target.level.toUpperCase(),
                                  style: TextStyle(
                                    color: targetColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 14,
                                    color: Colors.white70),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _currentTargetIndex = (_currentTargetIndex -
                                            1 +
                                            sorted.length) %
                                        sorted.length;
                                    _hasVibratedForTarget = false;
                                  });
                                  _flyToTarget(sorted[_currentTargetIndex]);
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: Colors.white70),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _currentTargetIndex =
                                        (_currentTargetIndex + 1) %
                                            sorted.length;
                                    _hasVibratedForTarget = false;
                                  });
                                  _flyToTarget(sorted[_currentTargetIndex]);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Image & Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _showImageZoomDialog(
                                context, target.photo, target.title),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: Image.network(
                                      target.photo,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.white12,
                                        child: const Icon(Icons.warning,
                                            color: Colors.amber, size: 24),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.zoom_in_rounded,
                                        color: Colors.white70, size: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  target.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${target.area} • ${target.kategori}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Proximity Visual Gauge (500m to 50m)
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: (1.0 -
                                                  ((distance - 50.0).clamp(
                                                          0.0, 450.0) /
                                                      450.0))
                                              .clamp(0.05, 1.0),
                                          minHeight: 4,
                                          backgroundColor: Colors.white12,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            isWithin50Meters
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFF00E5FF),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${distance.round()}M',
                                      style: TextStyle(
                                        color: isWithin50Meters
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF38BDF8),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tactical Action Bar
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isWithin50Meters
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isWithin50Meters
                                        ? const Color(0xFF86EFAC)
                                        : Colors.white12,
                                    width: isWithin50Meters ? 1.5 : 1,
                                  ),
                                ),
                                elevation: isWithin50Meters ? 6 : 0,
                                shadowColor: isWithin50Meters
                                    ? const Color(0xFF10B981).withOpacity(0.7)
                                    : null,
                              ),
                              onPressed: isWithin50Meters
                                  ? () {
                                      _showEncounterModal(
                                          context, target, distance,
                                          canTakeUp: true);
                                    }
                                  : () {
                                      _showTooFarWarning(context, distance);
                                    },
                              icon: Icon(
                                isWithin50Meters
                                    ? Icons.bolt_rounded
                                    : Icons.lock_outline_rounded,
                                size: 19,
                                color: isWithin50Meters
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                              ),
                              label: Text(
                                isWithin50Meters
                                    ? '⚡ AMANKAN TEMUAN (+50 XP)'
                                    : 'DEKATI TARGET (< 50M) • ${distance.round()}M',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                  color: isWithin50Meters
                                      ? Colors.white
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Fly Camera
                          Material(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _flyToTarget(target);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.all(11),
                                child: Icon(Icons.near_me_rounded,
                                    color: Color(0xFF00E5FF), size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Detail Button
                          Material(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                widget.onShowDetail(context, target.id);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.all(11),
                                child: Icon(Icons.info_outline_rounded,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedFilter = key;
          _currentTargetIndex = 0;
        });
        _updateMapGuide();
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withOpacity(0.25)
              : const Color(0xFF070B14).withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00E5FF)
                : Colors.white.withOpacity(0.15),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.3),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF94A3B8),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenModeButton(String key, String label) {
    final isSelected = _mapMode == key;
    return InkWell(
      onTap: () => _onSelectMode(key),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? Colors.black : const Color(0xFF94A3B8),
            letterSpacing: 0.2,
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

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
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

  // Approval Center State
  bool _isApprovalRegistered = false;
  int _pendingApprovalCount = 0;

  // Heatmap & Radar Proximity State ('heatmap', 'points', 'off')
  String _hazardMapMode = PreferenceService.getHazardMapMode();
  StreamSubscription<Position>? _positionStreamSub;
  Position? _lastUserPosition;
  DateTime? _lastPosJsUpdateTime;
  Position? _lastRadarCheckedPosition;
  bool _isFetchingHazards = false;
  bool _hasPlacedNearbyDemoHazard = false;
  MapHazardItem? _nearbyAlertHazard;
  double _nearbyDistance = 0;
  DateTime? _lastAlertTime;

  // Daftar hazard belum closed (30 hari terakhir)
  late List<MapHazardItem> _unclosedHazards;

  void _openFullscreenHazardHunter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _FullscreenHazardMapPage(
          html: _hazardMapHtml(
            mapMode: _hazardMapMode,
            userPosition: _lastUserPosition,
          ),
          initialMode: _hazardMapMode,
          unclosedHazards: _unclosedHazards,
          initialUserPosition: _lastUserPosition,
          onModeChanged: (mode) {
            _setMapMode(mode);
          },
          onCloseHazard: (modalCtx, id) {
            final matches = _unclosedHazards.where((item) => item.id == id);
            if (matches.isNotEmpty) {
              _showHazardCloseModal(modalCtx, matches.first);
            }
          },
          onShowDetail: (modalCtx, id) {
            final matches = _unclosedHazards.where((item) => item.id == id);
            if (matches.isNotEmpty) {
              _showHazardDetailModal(modalCtx, matches.first);
            }
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('===> DASHBOARD INIT STATE RUNNING <===');

    final cachedJson = PreferenceService.getCachedHazardMapJson();
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedJson) as List;
        _unclosedHazards = decoded
            .map((item) => MapHazardItem.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error restoring cached hazards: $e');
        _unclosedHazards = [];
      }
    } else {
      _unclosedHazards = [];
    }

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
            final matches = _unclosedHazards.where((h) => h.id == id);
            if (action == 'log') {
              debugPrint('[SafeMap JS Log] ${data['message']}');
            } else if (action == 'error') {
              debugPrint('[SafeMap JS Error] ${data['error']}');
            }
            if (matches.isNotEmpty) {
              final hazard = matches.first;
              if (action == 'detail') {
                _showHazardDetailModal(context, hazard);
              } else if (action == 'close') {
                _showHazardCloseModal(context, hazard);
              }
            }
          } catch (e) {
            debugPrint('Error on dashboard hazard bridge: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => debugPrint('[SafeMap] Page started: $url'),
          onPageFinished: (url) {
            debugPrint('[SafeMap] Page finished: $url');
            _injectCurrentPosition(_hazardMapCtrl);
          },
          onWebResourceError: (error) {
            debugPrint('[SafeMap] Resource error: code=${error.errorCode}, desc=${error.description}, url=${error.url}');
          },
        ),
      );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _searchList.addAll({
          for (var row in _rawData.toList()) row.title.replaceAll('\n', ' ')
        }.toList());
      });
      _fetchHomeBanners();
      _fetchNotifCount();
      _checkApprovalAccess();
      _checkSpecialPermitHighRiskAlerts();
      _initLocationAndProximity();
      _fetchHazardPointsFromApi();
    });
  }

  Future<void> _checkApprovalAccess() async {
    try {
      final res = await _api.checkApprovalCenterStatus();
      res.fold(
        (err) {},
        (data) {
          if (mounted) {
            final d = data['data'] as Map<String, dynamic>?;
            final isReg = d?['isRegistered'] as bool? ?? false;
            final pCount = d?['pendingCount'] as int? ?? 0;
            setState(() {
              _isApprovalRegistered = isReg;
              _pendingApprovalCount = pCount;
            });
          }
        },
      );
    } catch (_) {}
  }

  Future<void> _checkSpecialPermitHighRiskAlerts() async {
    try {
      final res = await _api.getSpecialPermitAlerts();
      res.fold(
        (err) {},
        (data) async {
          final alerts = (data['data'] as List<dynamic>?) ?? [];
          if (alerts.isNotEmpty && mounted) {
            final first = alerts.first as Map<String, dynamic>;
            final actType = (first['activityType'] ?? 'Pekerjaan Khusus').toString().replaceAll('_', ' ');
            final loc = first['workLocation'] ?? 'Area Operasional';

            await NotificationService.display(
              title: '⚠️ Peringatan Kegiatan High Risk!',
              body: 'Sedang ada kegiatan $actType di $loc. PJO & Inspector segera lakukan inspeksi di area kerja!',
              payload: '/special_permit',
              priority: 'urgent',
              notifType: 'special_permit',
            );
          }
        },
      );
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _positionStreamSub?.cancel();
      _positionStreamSub = null;
    } else if (state == AppLifecycleState.resumed) {
      _checkApprovalAccess();
      _checkSpecialPermitHighRiskAlerts();
      if (_positionStreamSub == null) {
        _initLocationAndProximity();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSub?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _fetchHazardPointsFromApi({Position? pos, bool force = false}) async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastFetchDate = PreferenceService.getHazardMapLastFetchDate();

    // Jika sudah pernah load hari ini dan cache tersedia, lewati panggilan API (1 hari sekali)
    if (!force && lastFetchDate == todayStr && _unclosedHazards.isNotEmpty) {
      debugPrint('[SafeMap] Menggunakan cache Safe Map hari ini ($todayStr), melewati panggilan network.');
      _reloadMap();
      return;
    }

    if (_isFetchingHazards) return;
    _isFetchingHazards = true;
    try {
      debugPrint('[SafeMap] Memuat titik Safe Map dari API (1x sehari / reload)...');
      final res = await _api.getSafeMapHazardPoints(
        days: 30,
        onlyOpen: true,
        limit: 80,
        lat: pos?.latitude ?? _lastUserPosition?.latitude,
        lon: pos?.longitude ?? _lastUserPosition?.longitude,
      );

      res.fold(
        (err) => debugPrint('Fetch safe map error: $err'),
        (points) {
          if (mounted) {
            final now = DateTime.now();
            final items = <MapHazardItem>[];

            for (final p in points) {
              final statusStr = p['status']?.toString() ?? 'Open';
              final statusLower = statusStr.toLowerCase();
              if (statusLower == 'closed' ||
                  statusLower == 'selesai' ||
                  statusLower == 'tutup') {
                continue;
              }

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
                if (p['tanggalIso'] != null) {
                  tgl = DateTime.tryParse(p['tanggalIso'].toString()) ?? now;
                } else if (p['tanggal'] != null) {
                  tgl = DateTime.tryParse(p['tanggal'].toString()) ?? now;
                }
              } catch (_) {}

              items.add(MapHazardItem(
                id: int.tryParse(p['id']?.toString() ?? '0') ?? 0,
                title: p['detail']?.toString() ??
                    p['temuan']?.toString() ??
                    'Temuan Hazard',
                area: p['area']?.toString() ?? 'Area Operasional',
                level: level,
                color: color,
                status: statusStr,
                statusColor: '#ef4444',
                lat: double.tryParse(p['lat']?.toString() ?? '0') ?? 0.0,
                lng: double.tryParse(
                        p['lon']?.toString() ?? p['lng']?.toString() ?? '0') ??
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
              ));
            }

            // Simpan cache 1 hari sekali
            PreferenceService.setCachedHazardMapPoints(
              jsonString: jsonEncode(items.map((e) => e.toJson()).toList()),
              dateStr: todayStr,
            );

            setState(() {
              _unclosedHazards = items;
            });
            _reloadMap();
          }
        },
      );
    } catch (e) {
      debugPrint('Error _fetchHazardPointsFromApi: $e');
    } finally {
      _isFetchingHazards = false;
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
        desiredAccuracy: LocationAccuracy.medium,
      );
      _onUserPositionUpdated(pos);

      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // Hemat baterai & suhu dingin
          distanceFilter: 15, // Hanya update jika berpindah 15 meter (tidak jitter di meja)
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

    final now = DateTime.now();
    // Throttle JS bridge update to at most once every 3 seconds to save GPU/CPU
    if (isFirstLoc || _lastPosJsUpdateTime == null || now.difference(_lastPosJsUpdateTime!).inSeconds >= 3) {
      _lastPosJsUpdateTime = now;
      _hazardMapCtrl.runJavaScript(
        'if(window.setUserLocation) window.setUserLocation(${pos.latitude}, ${pos.longitude}, ${pos.accuracy});',
      );
    }

    if (isFirstLoc && _unclosedHazards.isEmpty) {
      _fetchHazardPointsFromApi(pos: pos);
    }

    // Jika mode 'off', jangan lakukan deteksi radar dan jangan bergetar
    if (_hazardMapMode == 'off' || _unclosedHazards.isEmpty) return;

    // Throttle deteksi radar proximity: hanya jika berpindah minimal 8 meter dari titik check terakhir
    if (_lastRadarCheckedPosition != null) {
      final moved = Geolocator.distanceBetween(
        _lastRadarCheckedPosition!.latitude,
        _lastRadarCheckedPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (moved < 8.0) return;
    }
    _lastRadarCheckedPosition = pos;

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
    PreferenceService.setHazardMapMode(mode); // Simpan permanen ke lokal
    _hazardMapCtrl.runJavaScript(
      "if(window.setMapMode) window.setMapMode('$mode');",
    );
    if (mode == 'off') {
      _nearbyAlertHazard = null;
      _nearbyDistance = 0;
    }
  }

  void _reloadMap() {
    print('===> DASHBOARD RELOAD MAP: length=${_unclosedHazards.length} <===');
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
                          setModalState(
                              () => fotoPerbaikan = File(picked.path));
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
                                await _api.closeHazardDirect(
                                  hazard.id,
                                  text,
                                  closeMode: closeMode,
                                  fotoPerbaikan: fotoPerbaikan,
                                );
                              } catch (e) {
                                debugPrint('Closing api error: $e');
                              }

                              if (!mounted) return;
                              setModalState(() => isSaving = false);
                              Navigator.pop(ctx);

                              setState(() {
                                hazard.status = 'Closed';
                                _unclosedHazards.removeWhere(
                                    (item) => item.id == hazard.id);
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
          final photoUrl =
              rawPhoto.startsWith('/') ? '${_api.baseUrl}$rawPhoto' : rawPhoto;

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
    if (q.contains('mobil') ||
        q.contains('kendaraan') ||
        q.contains('unit') ||
        q.contains('truk') ||
        q.contains('p2h')) {
      return item.route.contains('p2h');
    }
    if (q.contains('roster') || q.contains('shift') || q.contains('jadwal')) {
      return item.route.contains('roster');
    }
    if (q.contains('p5m') || q.contains('sehat') || q.contains('fit')) {
      return item.route.contains('p5m');
    }
    if (q.contains('peringkat') ||
        q.contains('skor') ||
        q.contains('league') ||
        q.contains('poin')) {
      return item.route.contains('league') ||
          item.route.contains('achievement');
    }
    if (q.contains('insiden') ||
        q.contains('kecelakaan') ||
        q.contains('berita')) {
      return item.route.contains('incident') ||
          item.route.contains('information');
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
    if (q.contains('safety talk') ||
        q.contains('talk') ||
        q.contains('briefing')) {
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
      int count = 0;
      final counts = await _api.getNotificationCounts();
      count = counts['total'] ?? counts['unread'] ?? 0;
      final activeHazardCount = (counts['active_hazard_count'] as num?)?.toInt() ?? 0;
      final activeActionPlanCount = (counts['active_action_plan_count'] as num?)?.toInt() ?? 0;
      final unactionedCount = (counts['unactioned_count'] as num?)?.toInt() ?? 0;

      // Juga periksa apakah ada action_plans lokal di SQLite yang mengarah ke user
      int localCnt = 0;
      try {
        final db = DatabaseService();
        final localPlans =
            await db.rawQuery('''select count(*) as cnt from action_plans
               where deleted_at is null and ((pja_id=${_profile?.id} and status<1) or (pic_id=${_profile?.id} and status<2))''');
        if (localPlans.isNotEmpty && localPlans.first['cnt'] != null) {
          localCnt = (localPlans.first['cnt'] as num).toInt();
          count = count > localCnt ? count : localCnt;
        }
      } catch (_) {}

      // Tambahkan pending approval jika user memiliki permohonan persetujuan
      if (_pendingApprovalCount > 0) {
        count += _pendingApprovalCount;
      }

      int spAlertCount = 0;
      try {
        final spRes = await _api.getSpecialPermitAlerts();
        spRes.fold(
          (_) {},
          (spData) {
            final list = (spData['data'] as List<dynamic>?) ?? [];
            spAlertCount = list.length;
            count += spAlertCount;
          },
        );
      } catch (_) {}

      // GETARAN FISIK: Jika user dijadikan PIC / PJA temuan K3, ada Approval Menunggu, atau Special Permit High Risk
      if (activeHazardCount > 0 || activeActionPlanCount > 0 || localCnt > 0 || unactionedCount > 0 || _pendingApprovalCount > 0 || spAlertCount > 0) {
        NotificationService.vibrateForPicAssignment();
      }

      await PreferenceService.setNotif(count);
      if (mounted) {
        setState(() {
          _notifCount = count;
        });
      }
    } catch (_) {}
  }

  Widget _buildHomeBannerSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 15),
      child: Container(
        height: 172,
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
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
        height: 172,
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
            height: 172,
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
                    color: isCurrent
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFFCBD5E1),
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
      color: const Color(0xFF10233F),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => SafetyUpdatesPage(selectedIncident: banner)));
        },
        child: Stack(fit: StackFit.expand, children: [
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
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF10233F).withValues(alpha: 0.98),
                  const Color(0xFF10233F).withValues(alpha: 0.76),
                  const Color(0xFF10233F).withValues(alpha: 0.20),
                ],
                stops: const [0.0, 0.57, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: catColor.withValues(alpha: .55)),
                      ),
                      child: Icon(
                        (cat.contains('banner') || cat.contains('informasi'))
                            ? Icons.campaign_rounded
                            : Icons.warning_amber_rounded,
                        size: 18,
                        color: catColor,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(
                            'SAFETY UPDATE  •  ${banner.kategori.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFFD8E5F8),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .7))),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.white.withValues(alpha: .76)),
                      const SizedBox(width: 5),
                      Expanded(
                          child: Text(banner.lokasi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: .82),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600))),
                      const SizedBox(width: 8),
                      Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.arrow_forward_rounded,
                              size: 18, color: const Color(0xFF10233F))),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ]),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 12, color: Color(0xFF2563EB)),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                              const Text(
                                'SELAMAT DATANG',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _formatName(
                                    _profile?.namaLengkap ?? 'Karyawan'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.35,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _HomeNotificationButton(
                          count: _notifCount,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const NotifPage()),
                            );
                            _fetchNotifCount();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatName(_profile?.posisi ?? 'Staff'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCompany(_profile?.company),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
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
              // Quick Action Card: Approval Center (khusus user terdaftar di Bima)
              if (_isApprovalRegistered)
                _buildApprovalQuickCard(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                                    'Safe Map',
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
                                      '${_unclosedHazards.length} Radar Aktif',
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
                                'Peta sebaran & navigasi temuan bahaya aktif',
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
                        height: 425,
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
                            // Tombol Cepat Masuk Mode Hazard Hunter
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Material(
                                color:
                                    const Color(0xFF0F172A).withOpacity(0.88),
                                elevation: 4,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: () =>
                                      _openFullscreenHazardHunter(context),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: const Color(0xFF38BDF8),
                                          width: 1.2),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.radar_rounded,
                                            color: Color(0xFF38BDF8), size: 14),
                                        SizedBox(width: 5),
                                        Text(
                                          'SAFE MAPS',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 10,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                                              unclosedHazards: _unclosedHazards,
                                              initialUserPosition:
                                                  _lastUserPosition,
                                              onModeChanged: (mode) {
                                                _setMapMode(mode);
                                              },
                                              onCloseHazard: (modalCtx, id) {
                                                final matches = _unclosedHazards
                                                    .where((item) =>
                                                        item.id == id);
                                                if (matches.isNotEmpty) {
                                                  _showHazardCloseModal(
                                                      modalCtx, matches.first);
                                                }
                                              },
                                              onShowDetail: (modalCtx, id) {
                                                final matches = _unclosedHazards
                                                    .where((item) =>
                                                        item.id == id);
                                                if (matches.isNotEmpty) {
                                                  _showHazardDetailModal(
                                                      modalCtx, matches.first);
                                                }
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
              const SizedBox(height: 12),
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

  Widget _buildApprovalQuickCard() {
    final hasPending = _pendingApprovalCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ApprovalCenterPage(),
              ),
            ).then((_) => _checkApprovalAccess());
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: hasPending
                  ? const LinearGradient(
                      colors: [Color(0xFF0F2628), Color(0xFF134E4A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Colors.white, Color(0xFFF8FAFC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasPending
                    ? const Color(0xFF2DD4BF).withValues(alpha: 0.3)
                    : const Color(0xFFE2E8F0),
                width: hasPending ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasPending
                      ? const Color(0xFF0F2628).withValues(alpha: 0.25)
                      : const Color(0x0A000000),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: hasPending
                        ? const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: (hasPending ? const Color(0xFFEF4444) : const Color(0xFF0D9488))
                            .withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    hasPending ? Icons.pending_actions_rounded : Icons.fact_check_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                // Text Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Approval Center',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: hasPending ? Colors.white : const Color(0xFF0F2628),
                            ),
                          ),
                          if (hasPending) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_pendingApprovalCount Pending',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasPending
                            ? 'Ada $_pendingApprovalCount permohonan menunggu persetujuan Anda'
                            : 'Pantau alur & status pengajuan izin departemen',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: hasPending
                              ? Colors.white.withValues(alpha: 0.8)
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: hasPending ? const Color(0xFF2DD4BF) : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _hazardMapHtml({
    String mapMode = 'heatmap',
    Position? userPosition,
    List<MapHazardItem>? customHazards,
  }) {
    return buildHazardMapHtml(
      mapMode: mapMode,
      userPosition: userPosition ?? _lastUserPosition,
      hazards: customHazards ?? _unclosedHazards,
      baseUrl: _api.baseUrl,
    );
  }
}

String buildHazardMapHtml({
  String mapMode = 'heatmap',
  Position? userPosition,
  List<MapHazardItem> hazards = const [],
  String baseUrl = 'https://api_mbs.indexim.id',
}) {
  final hasUserPos = userPosition != null;
  final userLat = userPosition?.latitude ?? 1.2057;
  final userLng = userPosition?.longitude ?? 117.2247;
  final userAccuracy = userPosition?.accuracy ?? 10.0;
  final pointsJson = jsonEncode(hazards.map((e) => e.toJson()).toList());

  return '''
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <script>
      window.onerror = function(msg, url, line, col, err) {
        if (window.HazardBridge) {
          window.HazardBridge.postMessage(JSON.stringify({action: 'error', error: msg + ' at ' + url + ':' + line}));
        }
      };
      console.log = function() {
        var str = Array.prototype.slice.call(arguments).join(' ');
        if (window.HazardBridge) {
          window.HazardBridge.postMessage(JSON.stringify({action: 'log', message: str}));
        }
      };
    </script>
    <link rel="stylesheet" href="$baseUrl/leaflet/leaflet.css" />
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css" />
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="$baseUrl/leaflet/leaflet.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js"></script>
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
      .leaflet-control-attribution { display: none !important; }
      .leaflet-control-zoom { display: none !important; }
      .leaflet-popup-content-wrapper {
        border-radius: 14px;
        box-shadow: 0 12px 30px rgba(15, 23, 42, .22);
        padding: 4px;
      }
      .leaflet-popup { transition: opacity .14s ease-out; }
      .hazard-popup { width: 200px; padding: 2px; }
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
      
      .cluster-center-beacon {
        width: 32px;
        height: 32px;
        border-radius: 50%;
        background: #0f172a;
        border: 2.5px solid #38bdf8;
        box-shadow: 0 4px 14px rgba(0, 0, 0, 0.45);
        display: flex;
        align-items: center;
        justify-content: center;
        position: relative;
        cursor: pointer;
        transition: transform 0.2s cubic-bezier(0.34, 1.56, 0.64, 1);
      }
      .cluster-center-beacon:hover, .cluster-center-beacon:active {
        transform: scale(1.15);
      }
      .cluster-center-beacon .cluster-num {
        font-size: 13px;
        font-weight: 900;
        color: #ffffff;
        line-height: 1;
      }
      .cluster-center-beacon.is-expanded {
        background: #1e293b;
        border-color: #f43f5e !important;
        box-shadow: 0 0 14px rgba(244, 63, 94, 0.85);
      }
      .cluster-ping {
        position: absolute;
        inset: -4px;
        border-radius: 50%;
        border: 1.5px solid #38bdf8;
        opacity: 0.6;
        pointer-events: none;
      }
      .pin-cluster-subtag {
        position: absolute;
        top: -5px;
        right: -5px;
        background: #0f172a;
        color: #fff;
        border: 1.5px solid #ffffff;
        font-size: 8.5px;
        font-weight: 900;
        padding: 1px 3.5px;
        border-radius: 8px;
        line-height: 1;
        box-shadow: 0 2px 5px rgba(0,0,0,0.5);
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
        opacity: 0.5;
        pointer-events: none;
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
      let map = null;
      let heatLayer = null;
      let markerLayer = null;
      let userMarker = null;
      let userAccuracyCircle = null;
      let userCoordinates = $hasUserPos ? [$userLat, $userLng] : null;
      let targetGuideLine = null;
      let currentMode = '$mapMode';
      const allMarkersMap = {};
      const clusters = [];

      window.setMapMode = function(mode) {
        currentMode = mode;
        if (!map || !heatLayer || !markerLayer) return;
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

      window.setUserLocation = function(lat, lng, accuracy, heading) {
        if (window.renderUserMarker) {
          window.renderUserMarker(lat, lng, accuracy, true, heading);
        }
      };

      window.updateGuideLine = function(uLat, uLng, tLat, tLng, color) {
        if (targetGuideLine && map) {
          map.removeLayer(targetGuideLine);
          targetGuideLine = null;
        }
        if (!uLat || !uLng || !tLat || !tLng || !map) return;
        targetGuideLine = L.polyline([[uLat, uLng], [tLat, tLng]], {
          color: color || '#38bdf8',
          weight: 4,
          opacity: 0.9,
          dashArray: '10, 10',
          lineCap: 'round'
        }).addTo(map);
      };

      window.clearGuideLine = function() {
        if (targetGuideLine && map) { map.removeLayer(targetGuideLine); targetGuideLine = null; }
      };

      window.locateMe = function() {
        if (userCoordinates && map) {
          map.flyTo(userCoordinates, 16.5, { animate: true, duration: .55 });
          if (userMarker) setTimeout(() => userMarker.openPopup(), 600);
        }
      };

      function getHazardPopupHtml(point, isStacked, idx, N, clusterPoints) {
        const nextPoint = isStacked && clusterPoints ? clusterPoints[(idx + 1) % N] : null;
        return `
          <div class="hazard-popup">
            <img src="\${point.photo}" onerror="this.style.display='none'" />
            \${isStacked ? `
              <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:6px;padding:3px 7px;font-size:10px;font-weight:700;color:#1d4ed8;margin-bottom:6px;display:flex;align-items:center;justify-content:space-between">
                <span>📍 Titik Bersama</span>
                <span>Temuan \${idx + 1} dari \${N}</span>
              </div>
            ` : ''}
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
            \${isStacked && nextPoint ? `
              <button style="width:100%;padding:6px 0;background:#0f172a;color:#38bdf8;border:1px solid #0284c7;border-radius:8px;font-size:11px;font-weight:800;cursor:pointer;margin-top:5px" onclick="window.focusNextHazard(\${nextPoint.id})">
                🔄 Temuan Lain di Titik Ini (\${((idx + 1) % N) + 1}/\${N}) ➡
              </button>
            ` : ''}
          </div>
        `;
      }

      window.focusNextHazard = function(targetId) {
        const cluster = clusters.find(c => c.points && c.points.some(p => p.id === targetId));
        if (cluster && cluster.points.length > 1 && !cluster.isExpanded && cluster.expand) {
          cluster.expand();
        }

        setTimeout(() => {
          if (allMarkersMap[targetId]) {
            map.closePopup();
            setTimeout(() => {
              allMarkersMap[targetId].openPopup();
              if (window.HazardBridge) {
                window.HazardBridge.postMessage(JSON.stringify({ action: 'select', id: targetId }));
              }
            }, 120);
          }
        }, 80);
      };

      window.renderHazardPoints = function(points) {
        if (!map || !heatLayer || !markerLayer) return;
        heatLayer.clearLayers();
        markerLayer.clearLayers();
        for (var k in allMarkersMap) delete allMarkersMap[k];
        clusters.length = 0;

        const hazardPoints = points || [];
        hazardPoints.forEach((point, index) => {
          point._origIndex = index;
          let added = false;
          for (const c of clusters) {
            const dLat = (c.centerLat - point.lat);
            const dLng = (c.centerLng - point.lng);
            const distDeg = Math.sqrt(dLat * dLat + dLng * dLng);
            if (distDeg < 0.00018) {
              c.points.push(point);
              added = true;
              break;
            }
          }
          if (!added) {
            clusters.push({
              centerLat: point.lat,
              centerLng: point.lng,
              points: [point]
            });
          }
        });

        clusters.forEach((cluster) => {
          const N = cluster.points.length;
          const isStacked = N > 1;

          let topColor = cluster.points[0].color;
          if (cluster.points.some(p => p.level === 'Kritis' || p.level === 'Tinggi')) {
            topColor = '#ef4444';
          } else if (cluster.points.some(p => p.level === 'Sedang')) {
            topColor = '#f59e0b';
          }

          L.circle([cluster.centerLat, cluster.centerLng], {
            radius: 50,
            color: topColor,
            weight: 1.5,
            fillColor: topColor,
            fillOpacity: 0.22
          }).addTo(heatLayer);

          if (!isStacked) {
            const point = cluster.points[0];
            const showPing = point._origIndex < 15 && (point.level === 'Kritis' || point.level === 'Tinggi');
            const pinIcon = L.divIcon({
              className: '',
              html: `
                <div class="hazard-pin-wrap">
                  \${showPing ? `<div class="hazard-ping" style="background:\${point.color}"></div>` : ''}
                  <div class="hazard-pin-badge" style="background:\${point.color}">
                    <span>!</span>
                  </div>
                </div>
              `,
              iconSize: [28, 28],
              iconAnchor: [14, 28],
              popupAnchor: [0, -28]
            });

            const marker = L.marker([point.lat, point.lng], {
              icon: pinIcon,
              zIndexOffset: 300
            }).addTo(markerLayer);

            allMarkersMap[point.id] = marker;

            marker.on('click', function() {
              if (window.HazardBridge) {
                window.HazardBridge.postMessage(JSON.stringify({ action: 'select', id: point.id }));
              }
            });

            marker.bindPopup(getHazardPopupHtml(point, false, 0, 1), {
              maxWidth: 220,
              autoPan: true,
              autoPanPaddingTopLeft: [18, 90],
              autoPanPaddingBottomRight: [18, 28]
            });

          } else {
            cluster.isExpanded = false;
            cluster.elements = [];

            const radiusDeg = 0.00015 + (N > 3 ? 0.00004 : 0);

            function createBeaconHtml(isExpanded) {
              return `
                <div class="cluster-center-beacon \${isExpanded ? 'is-expanded' : ''}" style="border-color:\${isExpanded ? '#f43f5e' : topColor}">
                  \${!isExpanded ? `<div class="cluster-ping" style="border-color:\${topColor}"></div>` : ''}
                  <span class="cluster-num">\${isExpanded ? '✕' : N}</span>
                </div>
              `;
            }

            const centerIcon = L.divIcon({
              className: '',
              html: createBeaconHtml(false),
              iconSize: [32, 32],
              iconAnchor: [16, 16]
            });

            const clusterMarker = L.marker([cluster.centerLat, cluster.centerLng], {
              icon: centerIcon,
              zIndexOffset: 450
            }).addTo(markerLayer);

            cluster.collapse = function() {
              if (!cluster.isExpanded) return;
              cluster.isExpanded = false;
              clusterMarker.setIcon(L.divIcon({
                className: '',
                html: createBeaconHtml(false),
                iconSize: [32, 32],
                iconAnchor: [16, 16]
              }));
              cluster.elements.forEach(el => markerLayer.removeLayer(el));
              cluster.elements = [];
            };

            cluster.expand = function() {
              if (cluster.isExpanded) return;
              clusters.forEach(c => {
                if (c !== cluster && c.isExpanded && c.collapse) c.collapse();
              });

              cluster.isExpanded = true;
              clusterMarker.setIcon(L.divIcon({
                className: '',
                html: createBeaconHtml(true),
                iconSize: [32, 32],
                iconAnchor: [16, 16]
              }));

              cluster.points.forEach((point, idx) => {
                const angle = (2 * Math.PI * idx) / N - Math.PI / 2;
                const mLat = cluster.centerLat + radiusDeg * Math.cos(angle);
                const mLng = cluster.centerLng + (radiusDeg / Math.cos(cluster.centerLat * Math.PI / 180)) * Math.sin(angle);

                const leg = L.polyline([[cluster.centerLat, cluster.centerLng], [mLat, mLng]], {
                  color: point.color,
                  weight: 2,
                  opacity: 0.85,
                  dashArray: '3, 4'
                }).addTo(markerLayer);
                cluster.elements.push(leg);

                const pinIcon = L.divIcon({
                  className: '',
                  html: `
                    <div class="hazard-pin-wrap">
                      <div class="hazard-pin-badge" style="background:\${point.color}">
                        <span>!</span>
                      </div>
                      <span class="pin-cluster-subtag">\${idx + 1}/\${N}</span>
                    </div>
                  `,
                  iconSize: [28, 28],
                  iconAnchor: [14, 28],
                  popupAnchor: [0, -28]
                });

                const marker = L.marker([mLat, mLng], {
                  icon: pinIcon,
                  zIndexOffset: 550 + idx
                }).addTo(markerLayer);

                cluster.elements.push(marker);
                allMarkersMap[point.id] = marker;

                marker.on('click', function(ev) {
                  if (ev && ev.originalEvent) ev.originalEvent._clusterHandled = true;
                  if (window.HazardBridge) {
                    window.HazardBridge.postMessage(JSON.stringify({ action: 'select', id: point.id }));
                  }
                });

                marker.bindPopup(getHazardPopupHtml(point, true, idx, N, cluster.points), {
                  maxWidth: 220,
                  autoPan: true,
                  autoPanPaddingTopLeft: [18, 90],
                  autoPanPaddingBottomRight: [18, 28]
                });
              });
            };

            clusterMarker.on('click', function(ev) {
              if (ev && ev.originalEvent) ev.originalEvent._clusterHandled = true;
              if (cluster.isExpanded) {
                cluster.collapse();
              } else {
                cluster.expand();
              }
            });
          }
        });

        window.setMapMode(currentMode);
      };

      function initSafeMapEngine() {
        console.log('[SafeMap] initSafeMapEngine called, L is ' + (typeof L));
        if (typeof L === 'undefined') {
          setTimeout(initSafeMapEngine, 60);
          return;
        }
        if (window._safeMapStarted) return;
        window._safeMapStarted = true;

        const googleSat = L.tileLayer('https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', {
          subdomains: ['0', '1', '2', '3'],
          maxZoom: 20,
          maxNativeZoom: 19,
          keepBuffer: 1,
          updateWhenIdle: true,
          attribution: ''
        });

        const esriSat = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
          maxZoom: 20,
          maxNativeZoom: 17,
          keepBuffer: 1,
          updateWhenIdle: true,
          attribution: ''
        });

        const osm = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
          maxZoom: 19,
          attribution: ''
        });

        const hasUserPos = $hasUserPos;
        const initialUserLat = $userLat;
        const initialUserLng = $userLng;
        const initialAccuracy = $userAccuracy;

        map = L.map('map', {
          center: hasUserPos ? [initialUserLat, initialUserLng] : [1.0564, 117.7265],
          zoom: hasUserPos ? 16 : 13.5,
          maxZoom: 19,
          minZoom: 10,
          layers: [googleSat],
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

        googleSat.on('tileerror', function() {
          if (!map.hasLayer(esriSat)) map.addLayer(esriSat);
        });

        esriSat.on('tileerror', function() {
          if (!map.hasLayer(osm)) map.addLayer(osm);
        });

        map.on('click', function(e) {
          if (e.originalEvent && e.originalEvent._clusterHandled) return;
          clusters.forEach(c => {
            if (c.isExpanded && c.collapse) c.collapse();
          });
        });

        const hazardPoints = $pointsJson;
        heatLayer = L.layerGroup().addTo(map);
        markerLayer = L.layerGroup().addTo(map);

        window.renderUserMarker = function(lat, lng, accuracy, autoFly, heading) {
          userCoordinates = [lat, lng];
          if (userMarker) map.removeLayer(userMarker);
          if (userAccuracyCircle) map.removeLayer(userAccuracyCircle);

          const userIcon = L.divIcon({
            className: '',
            html: '<div class="user-location-arrow"><svg id="user-heading-arrow" style="transform:rotate(' + (heading || 18) + 'deg); transition: transform 0.3s ease-out;" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2 4.5 20.29l.71.71L12 18l6.79 3 .71-.71L12 2z"/></svg></div>',
            iconSize: [38, 38],
            iconAnchor: [19, 19]
          });
          userAccuracyCircle = L.circle(userCoordinates, {
            radius: Math.min(Math.max(accuracy || 10, 6), 15),
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
            map.setView(userCoordinates, 16);
          }
        };

        if (hasUserPos) {
          window.renderUserMarker(initialUserLat, initialUserLng, initialAccuracy, true);
        }

        window.renderHazardPoints(hazardPoints);

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

        setTimeout(() => map && map.invalidateSize(), 200);
        setTimeout(() => map && map.invalidateSize(), 600);
      }

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initSafeMapEngine);
      } else {
        initSafeMapEngine();
      }
      window.addEventListener('load', initSafeMapEngine);
      setTimeout(initSafeMapEngine, 250);
    </script>
  </body>
  </html>
  ''';
}

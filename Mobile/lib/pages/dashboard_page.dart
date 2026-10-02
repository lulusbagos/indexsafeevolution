import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/link_model.dart';
import '../models/profile_model.dart';
import '../services/api.dart';
import '../services/notification.dart';
import '../services/preference.dart';
import '../utils/helpers.dart';
import '../utils/links.dart';
import '../utils/routers.dart';
import '../widgets/ambient_background.dart';
import '../widgets/snackbar_msg.dart';
import 'menu/extra_page.dart';
import 'menu/ohs_page.dart';
import 'menu/sap_page.dart';
import 'notif_page.dart';
import 'safety_updates_page.dart';
import '../models/incident_news_model.dart';
import '../services/offline_sync_service.dart';
import '../services/security_check_service.dart';
import 'sync/pending_sync_page.dart';

class _HomeModuleCard extends StatelessWidget {
  const _HomeModuleCard({
    required this.title,
    required this.subLabel,
    required this.imagePath,
    required this.labelColor,
    required this.borderColor,
    required this.gradientColors,
    required this.onTap,
    this.iconHeight = 62,
  });

  final String title;
  final String subLabel;
  final String imagePath;
  final Color labelColor;
  final Color borderColor;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final double iconHeight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 124,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
            border: Border.all(color: borderColor, width: 1.2),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: labelColor.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 4),
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
                    width: 78,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: labelColor,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
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

class _HomeNotificationButton extends StatefulWidget {
  const _HomeNotificationButton({
    required this.unreadCount,
    required this.actionCount,
    required this.onTap,
  });

  final int unreadCount;
  final int actionCount;
  final VoidCallback onTap;

  @override
  State<_HomeNotificationButton> createState() => _HomeNotificationButtonState();
}

class _HomeNotificationButtonState extends State<_HomeNotificationButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _rotationAnim;
  late Animation<double> _scaleAnim;
  Timer? _periodicTimer;

  bool get _hasPending => widget.unreadCount > 0 || widget.actionCount > 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Animasi getaran/ayunan lonceng (wobble shake seperti lonceng sungguhan berdering)
    _rotationAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.22), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.22, end: 0.22), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.22, end: -0.15), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.12), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: -0.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.0), weight: 10),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 75),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    if (_hasPending) {
      _startShakeCycle();
    }
  }

  @override
  void didUpdateWidget(covariant _HomeNotificationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasPending) {
      if (_periodicTimer == null || !_periodicTimer!.isActive) {
        _startShakeCycle();
      }
    } else {
      _stopShakeCycle();
    }
  }

  void _startShakeCycle() {
    _shake();
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(milliseconds: 3200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_hasPending) {
        _shake();
      } else {
        timer.cancel();
      }
    });
  }

  void _stopShakeCycle() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    if (_animController.isAnimating) {
      _animController.stop();
    }
    _animController.reset();
  }

  Future<void> _shake() async {
    if (!mounted) return;
    try {
      // Getarkan perangkat selaras dengan getaran lonceng
      if (widget.actionCount > 0) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (_) {}

    try {
      if (mounted) {
        await _animController.forward(from: 0.0);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = _hasPending;
    final actionCount = widget.actionCount;
    final unreadCount = widget.unreadCount;

    return Semantics(
      button: true,
      label: hasPending
          ? 'Notifikasi: $unreadCount belum dibaca, $actionCount perlu tindakan'
          : 'Notifikasi',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: actionCount > 0
                    ? const Color(0xFFF59E0B)
                    : (unreadCount > 0 ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
                width: actionCount > 0 ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: actionCount > 0
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.22)
                      : (unreadCount > 0
                          ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.04)),
                  blurRadius: hasPending ? 10 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Ikon Lonceng yang bergetar/bergoyang secara dinamis
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: hasPending ? _scaleAnim.value : 1.0,
                      child: Transform.rotate(
                        angle: hasPending ? _rotationAnim.value : 0.0,
                        alignment: Alignment.topCenter,
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    actionCount > 0
                        ? Icons.notifications_active_rounded
                        : (unreadCount > 0
                            ? Icons.notifications_rounded
                            : Icons.notifications_none_rounded),
                    color: actionCount > 0
                        ? const Color(0xFFD97706)
                        : (unreadCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF334155)),
                    size: 22,
                  ),
                ),
                // Badge indikator unread & temuan action
                if (hasPending)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: actionCount > 0
                            ? const LinearGradient(
                                colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
                              )
                            : null,
                        color: actionCount > 0 ? null : const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: (actionCount > 0
                                    ? const Color(0xFFEA580C)
                                    : const Color(0xFFDC2626))
                                .withValues(alpha: 0.45),
                            blurRadius: 5,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (actionCount > 0) ...[
                            const Icon(Icons.bolt_rounded, size: 10, color: Colors.white),
                            Text(
                              actionCount > 99 ? '99+' : '$actionCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (unreadCount > 0)
                              Text(
                                '+$unreadCount',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ] else ...[
                            Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<Position?> _injectCurrentPosition(WebViewController controller) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await controller.runJavaScript(
      'window.setUserLocation(${position.latitude}, ${position.longitude}, ${position.accuracy});',
    );
    return position;
  } catch (error) {
    debugPrint('Gagal menampilkan posisi pengguna pada SafeMap: $error');
    return null;
  }
}

class _FullscreenSafeMapPage extends StatefulWidget {
  const _FullscreenSafeMapPage({
    required this.html,
    this.hazards = const [],
    this.onProximityAlert,
    this.onShowHazardDetail,
  });

  final String html;
  final List<Map<String, dynamic>> hazards;
  final Function(Map<String, dynamic>)? onProximityAlert;
  final Function(Map<String, dynamic>)? onShowHazardDetail;

  @override
  State<_FullscreenSafeMapPage> createState() => _FullscreenSafeMapPageState();
}

class _FullscreenSafeMapPageState extends State<_FullscreenSafeMapPage> {
  late final WebViewController _controller;
  Timer? _fullscreenGpsTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'SafeMapBridge',
        onMessageReceived: (message) {
          try {
            final data = jsonDecode(message.message);
            if (data is Map) {
              if (data['type'] == 'SHOW_HAZARD_DETAIL' || data['type'] == 'OPEN_HAZARD') {
                final hazardData = data['data'] != null
                    ? Map<String, dynamic>.from(data['data'])
                    : Map<String, dynamic>.from(data);
                if (data['distance'] != null) {
                  hazardData['initialDistance'] = data['distance'];
                }
                if (data['isInRadius'] != null) {
                  hazardData['initialIsInRadius'] = data['isInRadius'];
                }
                if (widget.onShowHazardDetail != null) {
                  widget.onShowHazardDetail!(hazardData);
                }
              } else if (data['type'] == 'NEARBY_HAZARD') {
                if (widget.onProximityAlert != null) {
                  widget.onProximityAlert!(Map<String, dynamic>.from(data));
                }
              } else if (data['type'] == 'REQUEST_LOCATION') {
                _injectCurrentPosition(_controller);
              }
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _injectCurrentPosition(_controller);
            if (widget.hazards.isNotEmpty) {
              try {
                final hJson = jsonEncode(widget.hazards);
                _controller.runJavaScript(
                  'if (typeof window.updateSafeMapPoints === "function") { window.updateSafeMapPoints($hJson); }',
                );
              } catch (_) {}
            }
          },
        ),
      )
      ..loadHtmlString(widget.html);

    _fullscreenGpsTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _injectCurrentPosition(_controller);
    });
  }

  @override
  void dispose() {
    _fullscreenGpsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.fullscreen_exit_rounded),
                    label: const Text('Perkecil Safe Map'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1D4ED8),
                      elevation: 5,
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
}

// Backward compatibility alias
typedef _FullscreenHazardMapPage = _FullscreenSafeMapPage;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  ProfileModel? get _profile => PreferenceService.getProfile();
  final _api = ApiService();
  ImageProvider? _profileImage;
  Timer? _safetyUpdateTimer;
  Timer? _proximityTimer;
  int _lastKnownUnread = -1;
  int _lastKnownUnactioned = -1;
  final _hazardMapCtrl = WebViewController();
  final Map<int, DateTime> _lastProximityAlerts = {};
  List<Map<String, dynamic>> _safeMapHazards = [];
  List<Map<String, dynamic>> _safeMapInspections = [];
  List<Map<String, dynamic>> _safeMapP5ms = [];
  List<Map<String, dynamic>> _safeMapSafetyTalks = [];
  final List<LinkMenuModel> _rawData = [
    ...listMenuSap,
    ...listMenuOhs1,
    ...listMenuOhs2,
    ...listMenuExtra
  ];
  final List<String> _searchList = [];
  bool _isDetailSheetOpen = false;
  int _homePendingOfflineCount = 0;
  Position? _currentUserPosition;

  List<IncidentNewsModel> _homeBanners = [];
  bool _isLoadingBanners = false;
  int _currentBannerIndex = 0;
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;

  void _onProfilePhotoNotifierChanged() {
    if (!mounted) return;
    _loadProfileImage();
    setState(() {});
  }

  Future<void> _checkHomePendingOffline() async {
    try {
      final count = await OfflineSyncService.instance.getPendingCount();
      if (mounted) {
        setState(() => _homePendingOfflineCount = count);
      }
    } catch (_) {}
  }

  Future<void> _fetchHomeBanners() async {
    if (_isLoadingBanners) return;
    _isLoadingBanners = true;
    final res = await _api.getHomeBanners(limit: 5);
    if (!mounted) return;
    res.fold(
      (err) {
        if (mounted) setState(() => _isLoadingBanners = false);
      },
      (banners) {
        if (mounted) {
          setState(() {
            _homeBanners = banners;
            _isLoadingBanners = false;
          });
          _startBannerTimer();
        }
      },
    );
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

  @override
  void initState() {
    super.initState();

    PreferenceService.profilePhotoNotifier.addListener(_onProfilePhotoNotifierChanged);
    _loadProfileImage();
    _fetchUnreadNotifCount();
    _checkSafetyUpdatesAndVibrate();
    _fetchSafeMapData();
    _checkHomePendingOffline();
    _fetchHomeBanners();

    final isPowerSaver = PreferenceService.isPowerSaverEnabled();
    final isAutoNotif = PreferenceService.isAutoNotifEnabled();

    // 1. Safety update polling: Hanya jalan secara berkala jika diaktifkan user di profil (mencegah HP panas)
    if (isAutoNotif) {
      _safetyUpdateTimer = Timer.periodic(const Duration(seconds: 90), (_) {
        _fetchUnreadNotifCount();
        _checkSafetyUpdatesAndVibrate();
        _checkHomePendingOffline();
      });
    }

    // 2. Proximity GPS: Gunakan interval sejuk (45 detik jika mode hemat baterai, 20 detik jika performa)
    final proxInterval = isPowerSaver ? const Duration(seconds: 45) : const Duration(seconds: 20);
    _proximityTimer = Timer.periodic(proxInterval, (_) async {
      final pos = await _injectCurrentPosition(_hazardMapCtrl);
      if (pos != null) {
        _currentUserPosition = pos;
        if (mounted) {
          SecurityCheckService.checkAndShowIfViolation(context, position: pos);
        }
      }
      _checkProximityAlerts();
    });

    // Cepatkan perolehan koordinat GPS agar SafeMap langsung membuka lokasi saya
    Geolocator.getLastKnownPosition().then((pos) {
      if (pos != null && mounted) {
        _currentUserPosition = pos;
        _injectCurrentPosition(_hazardMapCtrl);
      }
    });

    _hazardMapCtrl
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'SafeMapBridge',
        onMessageReceived: (message) {
          try {
            final data = jsonDecode(message.message);
            if (data is Map) {
              if (data['type'] == 'NEARBY_HAZARD') {
                _triggerHazardProximityVibration(
                  hazardId: (data['id'] as num?)?.toInt() ?? 0,
                  title: (data['title'] ?? 'Temuan Bahaya K3').toString(),
                  area: (data['area'] ?? 'Area Tambang').toString(),
                  distanceMeters: (data['distance'] as num?)?.toDouble() ?? 15.0,
                );
              } else if (data['type'] == 'SHOW_HAZARD_DETAIL' || data['type'] == 'OPEN_HAZARD') {
                final hazardData = data['data'] != null
                    ? Map<String, dynamic>.from(data['data'])
                    : Map<String, dynamic>.from(data);
                if (data['distance'] != null) {
                  hazardData['initialDistance'] = data['distance'];
                }
                if (data['isInRadius'] != null) {
                  hazardData['initialIsInRadius'] = data['isInRadius'];
                }
                _showHazardDetailAndCloseSheet(hazardData);
              } else if (data['type'] == 'REQUEST_LOCATION') {
                _injectCurrentPosition(_hazardMapCtrl);
              }
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            final pos = await _injectCurrentPosition(_hazardMapCtrl);
            if (pos != null) {
              _currentUserPosition = pos;
            }
            _updateSafeMapWebViewPoints();
          },
        ),
      )
      ..loadHtmlString(_safeMapHtml(initialPosition: _currentUserPosition));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() {
        _searchList.addAll({
          for (var row in _rawData.toList()) row.title.replaceAll('\n', ' ')
        }.toList());
      });

      // Periksa integritas K3 dan HANYA munculkan pop-up jika terdeteksi Fake GPS / VPN
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        SecurityCheckService.checkAndShowIfViolation(context, position: _currentUserPosition);
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    PreferenceService.profilePhotoNotifier.removeListener(_onProfilePhotoNotifierChanged);
    _safetyUpdateTimer?.cancel();
    _proximityTimer?.cancel();
    super.dispose();
  }

  void _triggerHazardProximityVibration({
    required int hazardId,
    required String title,
    required String area,
    required double distanceMeters,
  }) async {
    final now = DateTime.now();
    final lastAlert = _lastProximityAlerts[hazardId];
    if (lastAlert != null && now.difference(lastAlert).inMinutes < 3) {
      return; // Cooldown 3 menit per temuan agar tidak spam getar
    }
    _lastProximityAlerts[hazardId] = now;

    // Getar khas keselamatan: 3x getar kuat & jelas untuk alert bahaya
    try {
      for (int i = 0; i < 3; i++) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        await HapticFeedback.vibrate();
        await Future.delayed(const Duration(milliseconds: 250));
      }
    } catch (_) {}

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF991B1B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        duration: const Duration(seconds: 10),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TEMUAN K3 BELUM DICLOSE!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '~${distanceMeters.toStringAsFixed(0)}m',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Area: $area (Radius 20m)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'TINDAK LANJUT',
          textColor: Colors.amberAccent,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SapPage()),
            );
          },
        ),
      ),
    );
  }

  Future<void> _fetchSafeMapData() async {
    try {
      final res = await _api.getSafeMapPoints();
      res.fold(
        (err) {},
        (data) {
          if (data['data'] != null) {
            final d = data['data'];
            if (d['hazardPoints'] is List) {
              _safeMapHazards = List<Map<String, dynamic>>.from(d['hazardPoints']);
            }
            _updateSafeMapWebViewPoints();
          }
        },
      );
    } catch (_) {}
  }

  void _updateSafeMapWebViewPoints() {
    if (_safeMapHazards.isEmpty) return;
    try {
      final hJson = jsonEncode(_safeMapHazards);
      _hazardMapCtrl.runJavaScript('''
        if (typeof window.updateSafeMapPoints === 'function') {
          window.updateSafeMapPoints($hJson);
        }
      ''');
    } catch (_) {}
  }

  void _showHazardDetailAndCloseSheet(Map<String, dynamic> hazard) {
    if (_isDetailSheetOpen) return;
    _isDetailSheetOpen = true;
    final id = (hazard['id'] as num?)?.toInt() ?? 0;
    final area = (hazard['area'] ?? 'Area Tambang').toString();
    final detail = (hazard['detail'] ?? 'Temuan bahaya K3').toString();
    final resiko = (hazard['resiko'] ?? 'Sedang').toString();
    final pelapor = (hazard['nama'] ?? 'Karyawan').toString();
    final nikPelapor = (hazard['nik'] ?? '-').toString();
    final tanggal = (hazard['tanggal'] ?? '-').toString();
    final waktu = (hazard['waktu'] ?? '').toString();
    final departemen = (hazard['departemen'] ?? '-').toString();
    final pja = (hazard['pja'] ?? 'Foreman Lapangan').toString();
    final kategori = (hazard['kategoriBahaya'] ?? 'Kondisi Tidak Aman').toString();
    final jenis = (hazard['jenisBahaya'] ?? '-').toString();
    final hazardLat = (hazard['lat'] as num?)?.toDouble();
    final hazardLon = (hazard['lon'] as num?)?.toDouble();
    String? rawPhoto = hazard['photoUrl']?.toString();
    String? fullPhotoUrl;
    if (rawPhoto != null && rawPhoto.isNotEmpty) {
      if (rawPhoto.startsWith('http')) {
        fullPhotoUrl = rawPhoto;
      } else {
        fullPhotoUrl = '${_api.baseUrl}$rawPhoto';
      }
    }

    Color riskColor = const Color(0xFFF59E0B);
    final rLower = resiko.toLowerCase();
    if (rLower.contains('ekstrem') || rLower.contains('extreme') || rLower.contains('kritis')) {
      riskColor = const Color(0xFF991B1B);
    } else if (rLower.contains('tinggi') || rLower.contains('high')) {
      riskColor = const Color(0xFFDC2626);
    } else if (rLower.contains('rendah') || rLower.contains('low')) {
      riskColor = const Color(0xFF059669);
    }

    final actionCtrl = TextEditingController(
      text: 'Tindakan perbaikan telah dilaksanakan di lokasi dan kondisi area aman terkendali.',
    );
    bool isSubmitting = false;

    // Hitung jarak awal ke titik hazard
    double? currentDistance = (hazard['initialDistance'] as num?)?.toDouble();
    if (currentDistance == null && hazardLat != null && hazardLon != null && _currentUserPosition != null) {
      currentDistance = Geolocator.distanceBetween(
        _currentUserPosition!.latitude,
        _currentUserPosition!.longitude,
        hazardLat,
        hazardLon,
      );
    }

    bool isLocating = false;
    String? locationError;
    bool hasAutoFetchedLocation = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final currentStatus = (hazard['status'] ?? 'Open').toString();
          final isCurrentlyOpen = currentStatus.toLowerCase() != 'closed' && currentStatus.toLowerCase() != 'selesai';
          final currentPerbaikan = (hazard['perbaikan'] ?? hazard['tindakanPerbaikan'] ?? '').toString();

          // Fungsi interaktif untuk refresh GPS & recalculate jarak
          Future<void> refreshGpsDistance() async {
            setSheetState(() {
              isLocating = true;
              locationError = null;
            });
            try {
              if (!await Geolocator.isLocationServiceEnabled()) {
                setSheetState(() {
                  isLocating = false;
                  locationError = 'Layanan GPS perangkat belum aktif.';
                });
                return;
              }
              var perm = await Geolocator.checkPermission();
              if (perm == LocationPermission.denied) {
                perm = await Geolocator.requestPermission();
              }
              if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
                setSheetState(() {
                  isLocating = false;
                  locationError = 'Izin lokasi perangkat belum diizinkan.';
                });
                return;
              }
              final pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              );
              _currentUserPosition = pos;
              if (hazardLat != null && hazardLon != null) {
                final dist = Geolocator.distanceBetween(
                  pos.latitude,
                  pos.longitude,
                  hazardLat,
                  hazardLon,
                );
                setSheetState(() {
                  currentDistance = dist;
                  isLocating = false;
                  locationError = null;
                });
              } else {
                setSheetState(() {
                  isLocating = false;
                });
              }
            } catch (err) {
              setSheetState(() {
                isLocating = false;
                locationError = 'Gagal membaca koordinat GPS: $err';
              });
            }
          }

          if (isCurrentlyOpen && currentDistance == null && hazardLat != null && hazardLon != null && !hasAutoFetchedLocation && !isLocating) {
            hasAutoFetchedLocation = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              refreshGpsDistance();
            });
          }

          // Radius 20m Geofence: Hanya aktif jika dalam radius <= 20 meter
          final bool isInRadius = currentDistance != null && currentDistance! <= 20.0;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrentlyOpen ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCurrentlyOpen ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                          ),
                        ),
                        child: Icon(
                          isCurrentlyOpen ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                          size: 20,
                          color: isCurrentlyOpen ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              area,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'ID: #$id • $tanggal $waktu',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrentlyOpen ? const Color(0xFFDC2626) : const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCurrentlyOpen ? 'BELUM CLOSE' : 'CLOSED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fullPhotoUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                Image.network(
                                  fullPhotoUrl,
                                  height: 190,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 100,
                                    color: const Color(0xFFF1F5F9),
                                    alignment: Alignment.center,
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image_rounded, color: Colors.grey, size: 32),
                                        SizedBox(height: 4),
                                        Text('Foto temuan tidak dapat dimuat', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Foto Temuan Lapangan', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: riskColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: riskColor.withOpacity(0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.speed_rounded, size: 13, color: riskColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Risiko: $resiko',
                                    style: TextStyle(
                                      color: riskColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  kategori,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Kondisi Bahaya / Ketidaksesuaian',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            detail,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _buildInfoRow('Pelapor', '$pelapor ($nikPelapor)'),
                              const Divider(height: 14, color: Color(0xFFE2E8F0)),
                              _buildInfoRow('Departemen', departemen),
                              const Divider(height: 14, color: Color(0xFFE2E8F0)),
                              _buildInfoRow('Penanggung Jawab (PJA)', pja),
                              if (jenis != '-' && jenis.isNotEmpty) ...[
                                const Divider(height: 14, color: Color(0xFFE2E8F0)),
                                _buildInfoRow('Jenis Bahaya', jenis),
                              ],
                            ],
                          ),
                        ),
                        if (!isCurrentlyOpen && currentPerbaikan.isNotEmpty && currentPerbaikan != 'No') ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Tindakan Perbaikan yang Dilakukan',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF059669), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    currentPerbaikan,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF065F46),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (isCurrentlyOpen) ...[
                          // Banner Status Geofence / Radar 20m
                          if (isLocating) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Memverifikasi radius radar 20m di lokasi...',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ] else if (locationError != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.location_off_rounded, color: Color(0xFFD97706), size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'GPS Diperlukan untuk Close Temuan',
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF92400E)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    locationError!,
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: isLocating ? null : refreshGpsDistance,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFCD34D)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFB45309)),
                                          SizedBox(width: 4),
                                          Text(
                                            'Cek Ulang Lokasi GPS',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ] else if (!isInRadius) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFDC2626),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Fitur Close Temuan Terkunci',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: Color(0xFF991B1B),
                                          ),
                                        ),
                                      ),
                                      if (currentDistance != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '~${currentDistance!.toStringAsFixed(0)}m',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    currentDistance != null
                                        ? 'Jarak Anda saat ini ~${currentDistance!.toStringAsFixed(0)} meter dari titik temuan. Penutupan temuan hanya dapat dilakukan saat Anda memasuki area temuan (radius radar ≤ 20 meter).'
                                        : 'Penutupan temuan hanya dapat dilakukan saat Anda berada di lokasi fisik temuan (radius radar ≤ 20 meter).',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF7F1D1D),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: isLocating ? null : refreshGpsDistance,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFCA5A5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.refresh_rounded,
                                            size: 14,
                                            color: isLocating ? Colors.grey : const Color(0xFFDC2626),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isLocating ? 'Memperbarui...' : 'Perbarui Jarak Saya',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFDC2626),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF059669),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.radar_rounded, color: Colors.white, size: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Radar 20m Terverifikasi di Lokasi',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: Color(0xFF065F46),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF059669),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          currentDistance != null ? '~${currentDistance!.toStringAsFixed(0)}m • Aktif' : '≤ 20m • Aktif',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Posisi Anda terverifikasi di area temuan. Silakan lakukan tindakan fisik di lapangan, isi tindakan perbaikan di bawah, lalu close temuan ini.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF047857),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          const Text(
                            'Tindakan Perbaikan yang Dilakukan: *',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: actionCtrl,
                            maxLines: 2,
                            enabled: isInRadius && !isSubmitting,
                            readOnly: !isInRadius,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isInRadius ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                            ),
                            decoration: InputDecoration(
                              hintText: isInRadius
                                  ? 'Tuliskan tindakan perbaikan yang telah dilakukan di lapangan...'
                                  : 'Terkunci: Masuki radius 20 meter temuan untuk menginput tindakan perbaikan.',
                              filled: true,
                              fillColor: isInRadius ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: (!isInRadius || isSubmitting)
                                  ? null
                                  : () async {
                                      // Verifikasi GPS ganda sebelum API submit
                                      if (hazardLat != null && hazardLon != null) {
                                        try {
                                          final checkPos = await Geolocator.getCurrentPosition(
                                            desiredAccuracy: LocationAccuracy.high,
                                          );
                                          final freshDist = Geolocator.distanceBetween(
                                            checkPos.latitude,
                                            checkPos.longitude,
                                            hazardLat,
                                            hazardLon,
                                          );
                                          if (freshDist > 20.0) {
                                            setSheetState(() => currentDistance = freshDist);
                                            if (context.mounted) {
                                              SnackBarMsg.danger(
                                                context,
                                                'Akses ditolak: Anda berada di luar radius 20m (~${freshDist.toStringAsFixed(0)}m)! Harap dekati area temuan.',
                                              );
                                            }
                                            return;
                                          }
                                        } catch (_) {}
                                      }

                                      // Validasi Keamanan: Tolak jika terdeteksi Fake GPS (Mock Location) atau VPN
                                      final secAudit = await SecurityCheckService.instance.runFullAudit();
                                      if (secAudit.hasViolation) {
                                        if (context.mounted) {
                                          SecurityCheckService.showSecurityWarningDialog(
                                            context,
                                            forceAlert: true,
                                            currentStatus: secAudit,
                                          );
                                        }
                                        return;
                                      }

                                      final actionText = actionCtrl.text.trim();
                                      if (actionText.isEmpty) {
                                        SnackBarMsg.danger(context, 'Tindakan perbaikan wajib diisi!');
                                        return;
                                      }

                                      setSheetState(() => isSubmitting = true);

                                      await _api.closeHazardFromSafeMap(
                                        id: id,
                                        action: actionText,
                                      );

                                      hazard['status'] = 'Closed';
                                      hazard['perbaikan'] = actionText;
                                      for (var h in _safeMapHazards) {
                                        if (h['id'] == id) {
                                          h['status'] = 'Closed';
                                          h['perbaikan'] = actionText;
                                        }
                                      }

                                      try {
                                        _hazardMapCtrl.runJavaScript('''
                                          if (typeof window.updateHazardStatus === 'function') {
                                            window.updateHazardStatus($id, 'Closed', ${jsonEncode(actionText)});
                                          }
                                        ''');
                                      } catch (_) {}

                                      try {
                                        await HapticFeedback.heavyImpact();
                                      } catch (_) {}

                                      setSheetState(() => isSubmitting = false);

                                      if (mounted) {
                                        SnackBarMsg.success(
                                          context,
                                          'Temuan Hazard di $area berhasil di-close!',
                                        );
                                      }
                                    },
                              icon: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Icon(
                                      isInRadius ? Icons.task_alt_rounded : Icons.lock_rounded,
                                      size: 20,
                                    ),
                              label: Text(
                                isSubmitting
                                    ? 'Menyimpan & Menutup...'
                                    : isInRadius
                                        ? 'Tindak Lanjut & Close Temuan'
                                        : 'Hanya Bisa Ditutup di Lokasi Temuan (Radius ≤ 20m)',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFFE2E8F0),
                                disabledForegroundColor: const Color(0xFF94A3B8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SapPage()),
                                );
                              },
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              label: const Text(
                                'Buka di Menu SAP Lengkap',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Temuan Berhasil Ditutup (Closed)',
                                      style: TextStyle(
                                        color: Color(0xFF065F46),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                if (currentPerbaikan.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tindakan: $currentPerbaikan',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF047857),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Tutup Lembar Detail', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      _isDetailSheetOpen = false;
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkProximityAlerts() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final isPowerSaver = PreferenceService.isPowerSaverEnabled();
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: isPowerSaver ? LocationAccuracy.medium : LocationAccuracy.high,
      );

      // Periksa titik-titik hazard yang berstatus Open dalam radius 20 meter
      for (final h in _safeMapHazards) {
        final status = (h['status'] ?? '').toString().toLowerCase();
        if (status != 'open') continue;

        final lat = (h['lat'] as num?)?.toDouble();
        final lon = (h['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;

        final dist = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          lat,
          lon,
        );

        if (dist <= 20.0) {
          final id = (h['id'] as num?)?.toInt() ?? 0;
          final title = (h['detail'] ?? h['title'] ?? 'Temuan Bahaya K3').toString();
          final area = (h['area'] ?? 'Area Tambang').toString();

          _triggerHazardProximityVibration(
            hazardId: id,
            title: title,
            area: area,
            distanceMeters: dist,
          );
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchUnreadNotifCount() async {
    try {
      final counts = await _api.getNotificationCounts();
      final unread = counts['unread'] ?? 0;
      final unactioned = counts['unactioned'] ?? 0;

      // Jika ada notifikasi baru yang masuk saat aplikasi berjalan
      if (_lastKnownUnread != -1 && (unread > _lastKnownUnread || unactioned > _lastKnownUnactioned)) {
        final res = await _api.getNotifications(limit: 1);
        res.fold(
          (err) {},
          (list) {
            if (list.isNotEmpty) {
              final latest = list.first;
              NotificationService.display(
                title: latest.title,
                body: latest.message,
                payload: latest.url,
                notifType: latest.notifType,
              );
            }
          },
        );
      }

      _lastKnownUnread = unread;
      _lastKnownUnactioned = unactioned;
      PreferenceService.setNotifCounts(unread: unread, unactioned: unactioned);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _checkSafetyUpdatesAndVibrate() async {
    try {
      final res = await _api.getLatestIncident();
      res.fold(
        (err) {},
        (incident) async {
          final lastSeen = PreferenceService.getLastSeenIncidentId();
          if (lastSeen == 0) {
            await PreferenceService.setLastSeenIncidentId(incident.id);
            return;
          }

          if (incident.id > lastSeen) {
            await PreferenceService.setLastSeenIncidentId(incident.id);

            // HP BERGETAR KETIKA ADA SAFETY UPDATE TERBARU!
            try {
              for (int i = 0; i < 4; i++) {
                await HapticFeedback.heavyImpact();
                await Future.delayed(const Duration(milliseconds: 200));
                await HapticFeedback.vibrate();
                await Future.delayed(const Duration(milliseconds: 250));
              }
            } catch (_) {}

            NotificationService.display(
              title: '🚨 SAFETY UPDATE TERBARU!',
              body: '${incident.judul} (${incident.kategori}) - ${incident.lokasi}',
              notifType: 'hazard_new',
              payload: '/Incident/Index',
            );
          }
        },
      );
    } catch (_) {}
  }

  Future<void> _loadProfileImage() async {
    try {
      final curProfile = PreferenceService.getProfile();
      final foto = curProfile?.foto;
      if (foto == null || foto.trim().isEmpty) {
        if (mounted) setState(() => _profileImage = null);
        return;
      }

      final file = File(foto);
      if (await file.exists()) {
        if (!mounted) return;
        setState(() => _profileImage = FileImage(file));
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/$foto');
      if (await localFile.exists()) {
        if (!mounted) return;
        setState(() => _profileImage = FileImage(localFile));
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$foto');
      if (await tempFile.exists()) {
        if (!mounted) return;
        setState(() => _profileImage = FileImage(tempFile));
        return;
      }

      // 3. Remote URL support (full HTTP or relative /uploads or /api/profile/photo)
      if (foto.startsWith('http')) {
        if (!mounted) return;
        setState(() => _profileImage = NetworkImage(foto));
        return;
      }

      if (foto.startsWith('/uploads') || foto.startsWith('/api/')) {
        final serverUrl = '${_api.baseUrl}$foto';
        if (!mounted) return;
        setState(() => _profileImage = NetworkImage(serverUrl));
        return;
      }

      // Fallback: If NIK is known, query endpoint from backend
      if (curProfile?.noNik != null && curProfile!.noNik!.isNotEmpty && curProfile.noNik != '-') {
        final serverUrl = '${_api.baseUrl}/api/profile/photo/${curProfile.noNik}';
        if (!mounted) return;
        setState(() => _profileImage = NetworkImage(serverUrl));
        return;
      }

      if (!foto.startsWith('/') && !foto.contains('\\')) {
        await _api.dio.download(
          '${_api.baseUrl}/image/$foto',
          tempFile.path,
        );
        if (await tempFile.exists()) {
          if (!mounted) return;
          setState(() => _profileImage = FileImage(tempFile));
        }
      }
    } catch (e) {
      debugPrint('[Dashboard] Error loading profile image: $e');
    }
  }

  Future<void> _changeProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ubah Foto Profil',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Pilih sumber foto untuk disimpan di perangkat ini',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCCFBF1)),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF0D9488),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Kamera',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Ambil foto langsung dengan kamera ponsel',
                  style: TextStyle(fontSize: 11.5),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _processPickedImage(ImageSource.camera);
                },
              ),
              const Divider(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Galeri Foto',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Pilih dari galeri foto perangkat',
                  style: TextStyle(fontSize: 11.5),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _processPickedImage(ImageSource.gallery);
                },
              ),
              if (_profileImage != null) ...[
                const Divider(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Hapus Foto',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  subtitle: const Text(
                    'Kembalikan ke inisial nama',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePhoto();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPickedImage(ImageSource source) async {
    try {
      final picked = await pickImage(source: source);
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final ext = picked.path.split('.').last;
      final fileName =
          'avatar_${_profile?.id ?? 0}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final permanentFile = await picked.copy('${appDir.path}/$fileName');

      final curProfile = PreferenceService.getProfile();
      if (curProfile != null) {
        curProfile.foto = permanentFile.path;
        PreferenceService.setProfile(curProfile);
      } else {
        PreferenceService.setProfilePict(permanentFile.path);
      }

      if (!mounted) return;
      setState(() {
        _profileImage = FileImage(permanentFile);
      });

      _api.changeProfile(permanentFile).then((res) {
        res.fold(
          (err) => debugPrint('[Dashboard] Upload warning: $err'),
          (data) {
            final serverFoto = data['foto']?.toString() ?? data['url']?.toString();
            if (serverFoto != null) {
              final p = PreferenceService.getProfile();
              if (p != null) {
                p.foto = serverFoto;
                PreferenceService.setProfile(p);
              }
            }
          },
        );
      }).catchError((_) {});

      SnackBarMsg.success(context, 'Foto profil berhasil diperbarui!');
    } catch (e) {
      debugPrint('Error saving profile image: $e');
      if (mounted) {
        SnackBarMsg.danger(context, 'Gagal menyimpan foto profil: $e');
      }
    }
  }

  void _removeProfilePhoto() {
    final curProfile = PreferenceService.getProfile();
    if (curProfile != null) {
      curProfile.foto = '';
      PreferenceService.setProfile(curProfile);
    } else {
      PreferenceService.setProfilePict('');
    }
    setState(() {
      _profileImage = null;
    });
    SnackBarMsg.info(context, 'Foto profil dihapus, kembali ke inisial nama.');
  }

  String _formatTitleCase(String? name) {
    if (name == null || name.trim().isEmpty) return 'Karyawan';
    return name.trim().split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() +
          (w.length > 1 ? w.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'K';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  String _getGreetingText() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Semangat Pagi';
    if (hour < 15) return 'Semangat Siang';
    if (hour < 18) return 'Semangat Sore';
    return 'Semangat Malam';
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Sleek, Simple & Professional User Profile Card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x060F172A),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Circular Profile Avatar with Tap Action
                      InkWell(
                        onTap: _changeProfilePhoto,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _profileImage == null
                                ? const LinearGradient(
                                    colors: [Color(0xFF1E3A8A), Color(0xFF0284C7)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            image: _profileImage != null
                                ? DecorationImage(
                                    image: _profileImage!,
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                          ),
                          child: _profileImage == null
                              ? Center(
                                  child: Text(
                                    _getInitials(_profile?.namaLengkap),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 13),
                      // Greeting, Name & Role/NIK
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${_getGreetingText()},',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blueGrey.shade500,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Text('👋', style: TextStyle(fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _formatTitleCase(_profile?.namaLengkap),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (_profile?.noNik != null && _profile!.noNik!.isNotEmpty) ...[
                                  Text(
                                    _profile!.noNik!,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  Text(
                                    '  •  ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    (_profile?.posisi != null && _profile!.posisi!.trim().isNotEmpty)
                                        ? _profile!.posisi!.trim()
                                        : (_profile?.depart ?? (_profile?.company ?? 'Karyawan Indexsafe')),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blueGrey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Notification Bell
                      _HomeNotificationButton(
                        unreadCount: PreferenceService.getNotifUnread(),
                        actionCount: PreferenceService.getNotifUnactioned(),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const NotifPage()),
                          );
                          _fetchUnreadNotifCount();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Modern Search Bar with Autocomplete
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue txtValue) {
                    if (txtValue.text.trim().isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return _searchList.where((String option) {
                      return option
                          .toLowerCase()
                          .contains(txtValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    var vals = _rawData
                        .where((e) =>
                            e.title.replaceAll('\n', ' ') == selection)
                        .toList();
                    if (vals.isNotEmpty) {
                      routePage(context, vals.first.route,
                          title: vals.first.title);
                    }
                  },
                  fieldViewBuilder:
                      (context, textController, focusNode, onFieldSubmitted) {
                    return Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A)
                                .withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF0D9488),
                            size: 21,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: textController,
                              focusNode: focusNode,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Cari menu, SOP, atau fitur...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.normal,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: textController,
                            builder: (context, value, _) {
                              if (value.text.isEmpty) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  child: Material(
                                    color: const Color(0xFFF0FDFA),
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      onTap: () => focusNode.requestFocus(),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFFCCFBF1),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.search_rounded,
                                              size: 13,
                                              color: Color(0xFF0D9488),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Cari',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0D9488),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18),
                                color: Colors.grey.shade500,
                                onPressed: () => textController.clear(),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // 3. Featured Banner (Dynamic Incident Flash & Safety First)
            _buildHomeBannerSection(),

            // 3.5 Banner Antrian Data Belum Sinkron (Offline Outbox)
            if (_homePendingOfflineCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PendingSyncPage(),
                        ),
                      );
                      _checkHomePendingOffline();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.cloud_off_rounded,
                              color: Color(0xFFD97706),
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_homePendingOfflineCount Data Offline Belum Terkirim',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'Data tersimpan di HP. Tap untuk kirim ke server.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Kirim',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 4. Main Modules (SAP, OHS, Performance Hub)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _HomeModuleCard(
                      title: 'SAP',
                      subLabel: 'Operasional',
                      imagePath: 'assets/images/home-sap.png',
                      labelColor: const Color(0xFF1E40AF),
                      borderColor: const Color(0xFFBFDBFE),
                      gradientColors: const [Colors.white, Color(0xFFF0F7FF)],
                      iconHeight: 64,
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
                      subLabel: 'Keselamatan',
                      imagePath: 'assets/images/home-ohs.png',
                      labelColor: const Color(0xFF0D9488),
                      borderColor: const Color(0xFF99F6E4),
                      gradientColors: const [Colors.white, Color(0xFFF0FDF9)],
                      iconHeight: 66,
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
                      title: 'Performance\nHub',
                      subLabel: 'Monitoring',
                      imagePath: 'assets/images/home-performance-hub.png',
                      labelColor: const Color(0xFFD97706),
                      borderColor: const Color(0xFFFDE68A),
                      gradientColors: const [Colors.white, Color(0xFFFFFBEB)],
                      iconHeight: 60,
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

            // 5. Safe Map Section Header & Card (Matching /Performance/Index)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header SafeMap: Modern, High-Tech, Executive K3 Telemetry
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          size: 22,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'SafeMap',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, size: 6, color: Color(0xFF16A34A)),
                                      SizedBox(width: 4),
                                      Text(
                                        'LIVE GPS',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Pemantauan Kondisi Bahaya & Area Kerja Pit',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      height: 355,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
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
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      fullscreenDialog: true,
                                      builder: (context) =>
                                          _FullscreenSafeMapPage(
                                        html: _safeMapHtml(initialPosition: _currentUserPosition),
                                        hazards: _safeMapHazards,
                                        onShowHazardDetail: (data) {
                                          _showHazardDetailAndCloseSheet(data);
                                        },
                                        onProximityAlert: (data) {
                                          _triggerHazardProximityVibration(
                                            hazardId: (data['id'] as num?)?.toInt() ?? 0,
                                            title: (data['title'] ?? 'Temuan Bahaya K3').toString(),
                                            area: (data['area'] ?? 'Area Tambang').toString(),
                                            distanceMeters: (data['distance'] as num?)?.toDouble() ?? 15.0,
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.fullscreen_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Batas Bawah: Disesuaikan agar seluruh card map (legend & tombol lokasi) terlihat utuh di atas navbar
            SizedBox(
              height: 94 + MediaQuery.of(context).padding.bottom,
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  String _hazardMapHtml() => _safeMapHtml();

  String _safeMapHtml({Position? initialPosition}) {
    final pos = initialPosition ?? _currentUserPosition;
    final initLat = pos?.latitude.toString() ?? '1.2057';
    final initLng = pos?.longitude.toString() ?? '117.2247';
    final initZoom = pos != null ? '17' : '15';

    final html = r'''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <style>
        * { box-sizing: border-box; }
        html, body {
          height: 100%;
          width: 100%;
          margin: 0;
          padding: 0;
          overflow: hidden;
          background: #0f172a;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          color: #f8fafc;
        }
        #container {
          position: relative;
          height: 100%;
          width: 100%;
        }
        #map {
          width: 100%;
          height: 100%;
          background: #090d16;
        }
        .leaflet-control-attribution {
          display: none !important;
        }
        /* Top Status Bar: Hazard Only, Bersih & Profesional */
        .safemap-top-bar {
          position: absolute;
          top: 10px;
          left: 10px;
          right: 56px;
          z-index: 999;
          background: rgba(15, 23, 42, 0.92);
          backdrop-filter: blur(8px);
          -webkit-backdrop-filter: blur(8px);
          border: 1px solid rgba(255, 255, 255, 0.14);
          border-radius: 12px;
          padding: 6px 12px;
          display: flex;
          align-items: center;
          justify-content: space-between;
          box-shadow: 0 4px 16px rgba(0, 0, 0, 0.35);
          pointer-events: auto;
        }
        /* Leaflet Zoom Control: Posisikan rapi di bawah status bar agar tidak tumpang tindih */
        .leaflet-top.leaflet-left .leaflet-control-zoom {
          margin-top: 54px !important;
          margin-left: 10px !important;
          border-radius: 10px !important;
          overflow: hidden !important;
          border: 1px solid rgba(255, 255, 255, 0.18) !important;
          box-shadow: 0 4px 14px rgba(0, 0, 0, 0.45) !important;
        }
        .leaflet-control-zoom a {
          background: rgba(15, 23, 42, 0.92) !important;
          color: #f8fafc !important;
          border-bottom: 1px solid rgba(255, 255, 255, 0.12) !important;
          backdrop-filter: blur(8px);
          width: 32px !important;
          height: 32px !important;
          line-height: 32px !important;
          font-size: 15px !important;
        }
        .leaflet-control-zoom a:hover, .leaflet-control-zoom a:active {
          background: #1e293b !important;
          color: #38bdf8 !important;
        }
        .safemap-title-wrap {
          display: flex;
          align-items: center;
          gap: 7px;
        }
        .pulse-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: #ef4444;
          box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7);
          animation: pulseRed 1.8s infinite;
        }
        @keyframes pulseRed {
          0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7); }
          70% { transform: scale(1); box-shadow: 0 0 0 8px rgba(239, 68, 68, 0); }
          100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(239, 68, 68, 0); }
        }
        .safemap-title {
          font-size: 11.5px;
          font-weight: 800;
          color: #ffffff;
          letter-spacing: -0.2px;
        }
        .safemap-sub {
          font-size: 9.5px;
          color: #94a3b8;
          font-weight: 600;
        }
        .safemap-badge-open {
          background: #dc2626;
          color: #ffffff;
          font-size: 10px;
          font-weight: 800;
          padding: 2px 7px;
          border-radius: 20px;
          white-space: nowrap;
          border: 1px solid rgba(255,255,255,0.25);
        }
        /* Floating Locate Button */
        .safemap-locate-btn {
          position: absolute;
          bottom: 16px;
          right: 12px;
          z-index: 999;
          background: #1e293b;
          color: #ffffff;
          border: 1.5px solid #475569;
          border-radius: 10px;
          padding: 7px 11px;
          font-size: 11px;
          font-weight: 700;
          display: flex;
          align-items: center;
          gap: 5px;
          cursor: pointer;
          box-shadow: 0 4px 14px rgba(0, 0, 0, 0.4);
        }
        .safemap-locate-btn:active {
          background: #334155;
        }
        /* Compact Legend */
        .legend-pin {
          position: absolute;
          bottom: 16px;
          left: 10px;
          z-index: 999;
          background: rgba(15, 23, 42, 0.94);
          border: 1.5px solid #334155;
          border-radius: 10px;
          padding: 8px 10px;
          font-size: 10px;
          color: #f8fafc;
          box-shadow: 0 4px 14px rgba(0,0,0,0.4);
          pointer-events: none;
        }
        .legend-pin-title {
          font-weight: 800;
          color: #38bdf8;
          margin-bottom: 4px;
          text-transform: uppercase;
        }
        .legend-pin-row {
          display: flex;
          align-items: center;
          gap: 6px;
          margin-top: 3px;
        }
        .legend-pin-dot {
          width: 9px;
          height: 9px;
          border-radius: 50%;
          border: 1px solid #ffffff;
          flex-shrink: 0;
        }
        /* User Radar Marker */
        .user-marker-pulse {
          width: 30px;
          height: 30px;
          display: flex;
          align-items: center;
          justify-content: center;
          border-radius: 50%;
          background: #ffffff;
          border: 2.5px solid #2563eb;
          box-shadow: 0 0 0 6px rgba(37, 99, 235, 0.25);
          position: relative;
        }
        .user-marker-pulse::after {
          content: '';
          position: absolute;
          inset: -8px;
          border: 2px solid rgba(37, 99, 235, 0.45);
          border-radius: 50%;
          animation: userRadar 1.8s ease-out infinite;
        }
        @keyframes userRadar {
          0% { transform: scale(.7); opacity: 1; }
          100% { transform: scale(1.6); opacity: 0; }
        }
        /* Hazard Dot Markers */
        .hazard-pin-wrapper {
          background: transparent !important;
          border: none !important;
        }
        .hazard-dot {
          width: 26px;
          height: 26px;
          border-radius: 50%;
          border: 2.5px solid #ffffff;
          box-shadow: 0 3px 10px rgba(0, 0, 0, 0.65);
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: transform 0.15s ease;
          pointer-events: auto !important;
        }
        .hazard-dot:active {
          transform: scale(1.3);
        }
        .hazard-inner-dot {
          width: 7px;
          height: 7px;
          border-radius: 50%;
          background: #ffffff;
          box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
        }
        .dot-pulse {
          animation: hazardPulse 1.9s infinite;
        }
        @keyframes hazardPulse {
          0% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.75); }
          70% { box-shadow: 0 0 0 12px rgba(239, 68, 68, 0); }
          100% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0); }
        }
        /* Popup */
        .leaflet-popup-content-wrapper {
          background: #ffffff !important;
          border-radius: 14px !important;
          box-shadow: 0 12px 30px rgba(15, 23, 42, 0.3) !important;
          padding: 0 !important;
          overflow: hidden;
        }
        .leaflet-popup-content {
          margin: 12px 14px !important;
          line-height: 1.35;
        }
        .hitsafe-popup {
          width: 220px;
          color: #0f172a;
          font-size: 11.5px;
        }
        .hitsafe-popup-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          border-bottom: 1px solid #e2e8f0;
          padding-bottom: 6px;
          margin-bottom: 6px;
        }
        .hitsafe-popup-title {
          font-weight: 800;
          font-size: 13px;
          color: #0f172a;
        }
        .hitsafe-badge {
          display: inline-block;
          padding: 2px 7px;
          border-radius: 20px;
          font-size: 9.5px;
          font-weight: 800;
          text-transform: uppercase;
        }
        .badge-open { background: #fee2e2; color: #b91c1c; }
        .badge-closed { background: #d1fae5; color: #065f46; }
        .hitsafe-popup img {
          width: 100%;
          height: 95px;
          object-fit: cover;
          border-radius: 8px;
          margin-bottom: 6px;
          border: 1px solid #cbd5e1;
        }
        .hitsafe-popup-detail {
          background: #f8fafc;
          border: 1px solid #e2e8f0;
          border-radius: 6px;
          padding: 6px 8px;
          margin-bottom: 8px;
          color: #334155;
          font-size: 11px;
        }
        .hitsafe-popup-btn {
          width: 100%;
          background: #059669;
          color: #ffffff;
          border: none;
          border-radius: 8px;
          padding: 7px 10px;
          font-weight: 800;
          font-size: 11px;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 4px;
        }
        .hitsafe-popup-btn:active {
          background: #047857;
        }
        /* Active Radar 20m Marker pulse */
        .radar-active-hazard {
          animation: radarActivePing 1.2s infinite ease-out !important;
          border: 3px solid #fef08a !important;
          box-shadow: 0 0 16px rgba(239, 68, 68, 0.95) !important;
        }
        @keyframes radarActivePing {
          0% { transform: scale(1); box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.85); }
          50% { transform: scale(1.22); box-shadow: 0 0 0 14px rgba(239, 68, 68, 0); }
          100% { transform: scale(1); box-shadow: 0 0 0 0 rgba(239, 68, 68, 0); }
        }
        .radar-active-circle {
          stroke-linecap: round;
          stroke-dasharray: 6 6;
          animation: radarCirclePulse 2s ease-in-out infinite;
        }
        @keyframes radarCirclePulse {
          0% { stroke-opacity: 0.7; fill-opacity: 0.16; }
          50% { stroke-opacity: 1; fill-opacity: 0.34; }
          100% { stroke-opacity: 0.7; fill-opacity: 0.16; }
        }
      </style>
    </head>
    <body>
      <div id="container">
        <!-- Top Status Bar (Hazard Only, Bersih & Satelit Murni) -->
        <div class="safemap-top-bar">
          <div class="safemap-title-wrap">
            <div id="radarPulseDot" class="pulse-dot"></div>
            <div>
              <div class="safemap-title">SafeMap Satelit • Operasional Pit</div>
              <div id="safemapSubtitle" class="safemap-sub">Periode Berjalan • Status Siaga</div>
            </div>
          </div>
          <div id="badgeOpenCount" class="safemap-badge-open">...</div>
        </div>

        <!-- Map Canvas -->
        <div id="map"></div>

        <!-- Floating Locate GPS Button -->
        <button id="btnLocate" class="safemap-locate-btn" type="button">⌖ Lokasi Saya</button>

        <!-- Floating Legend -->
        <div id="legendPin" class="legend-pin">
          <div class="legend-pin-title">Tingkat Risiko Hazard</div>
          <div class="legend-pin-row"><span class="legend-pin-dot" style="background:#991b1b"></span>Ekstrem (Open)</div>
          <div class="legend-pin-row"><span class="legend-pin-dot" style="background:#ef4444"></span>Tinggi (Open)</div>
          <div class="legend-pin-row"><span class="legend-pin-dot" style="background:#f59e0b"></span>Sedang (Open)</div>
          <div class="legend-pin-row"><span class="legend-pin-dot" style="background:#10b981"></span>Selesai / Closed</div>
          <div style="margin-top:5px;padding-top:4px;border-top:1px solid #334155;color:#38bdf8;font-weight:700">
            🎯 Deteksi Area: Otomatis saat mendekati temuan
          </div>
        </div>
      </div>

      <script>
        // Tampilan Satelit Murni ArcGIS World Imagery (Tanpa Street)
        const satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
          maxZoom: 19,
          attribution: ''
        });

        // Inisialisasi Peta - Langsung berpusat ke lokasi
        const map = L.map('map', {
          center: [__INIT_LAT__, __INIT_LNG__],
          zoom: __INIT_ZOOM__,
          layers: [satellite],
          zoomControl: true,
          attributionControl: false,
          tap: false
        });

        const markersLayer = L.layerGroup().addTo(map);
        const radarCirclesLayer = L.layerGroup().addTo(map);

        let userCoordinates = null;
        let userMarker = null;
        let userAccuracyCircle = null;
        let hasCenteredOnUser = false;

        let allPoints = [];

        function postBridgeMessage(payload) {
          try {
            const msg = typeof payload === 'string' ? payload : JSON.stringify(payload);
            if (window.SafeMapBridge && typeof window.SafeMapBridge.postMessage === 'function') {
              window.SafeMapBridge.postMessage(msg);
            } else if (typeof SafeMapBridge !== 'undefined' && typeof SafeMapBridge.postMessage === 'function') {
              SafeMapBridge.postMessage(msg);
            }
          } catch (err) {
            console.error('Bridge error:', err);
          }
        }

        window.onHazardDotClick = function(id) {
          const p = allPoints.find(item => item.id == id);
          if (p) {
            let dist = null;
            let inRadius = false;
            if (userCoordinates && p.lat && p.lon) {
              dist = L.latLng(userCoordinates[0], userCoordinates[1]).distanceTo(L.latLng(p.lat, p.lon));
              inRadius = dist <= 20.0;
            }
            postBridgeMessage({
              type: 'SHOW_HAZARD_DETAIL',
              data: p,
              distance: dist,
              isInRadius: inRadius
            });
          }
        };

        function getMarkerColor(point) {
          const status = String(point.status || '').toLowerCase();
          const risk = String(point.resiko || '').toLowerCase();

          if (status === 'closed' || status === 'close' || status === 'selesai') {
            return '#10b981';
          }
          if (risk.includes('extreme') || risk.includes('ekstrem') || risk.includes('kritis')) {
            return '#991b1b';
          }
          if (risk.includes('high') || risk.includes('tinggi')) {
            return '#ef4444';
          }
          if (risk.includes('medium') || risk.includes('sedang')) {
            return '#f59e0b';
          }
          return '#3b82f6';
        }

        // Radar 20m HANYA aktif saat user memasuki area temuan (dist <= 20.0m)
        function updateRadarZones() {
          radarCirclesLayer.clearLayers();
          if (!userCoordinates) return;

          const userLatLng = L.latLng(userCoordinates[0], userCoordinates[1]);
          let activeHazardsInRange = [];

          allPoints.forEach(p => {
            const statusLower = String(p.status || '').toLowerCase();
            const isOpen = statusLower !== 'closed' && statusLower !== 'close' && statusLower !== 'selesai';
            const dotEl = document.getElementById('hazard-dot-' + p.id);

            if (isOpen && p.lat && p.lon) {
              const dist = userLatLng.distanceTo(L.latLng(p.lat, p.lon));

              // RADAR 20 METER AKTIF JIKA MEMASUKI AREA TEMUAN (Radius <= 20m)
              if (dist <= 20.0) {
                activeHazardsInRange.push({ point: p, dist: dist });

                // Gambar Lingkaran Radar 20M Berdenyut Aktif pada temuan yang dimasuki
                L.circle([p.lat, p.lon], {
                  radius: 20,
                  color: '#ef4444',
                  weight: 2,
                  className: 'radar-active-circle',
                  fillColor: '#ef4444',
                  fillOpacity: 0.22,
                  interactive: false
                }).addTo(radarCirclesLayer);

                if (dotEl) {
                  dotEl.classList.add('radar-active-hazard');
                }
              } else {
                if (dotEl) {
                  dotEl.classList.remove('radar-active-hazard');
                }
              }
            } else {
              if (dotEl) {
                dotEl.classList.remove('radar-active-hazard');
              }
            }
          });

          // Update Status Subtitle & Pulse Dot
          const subTitle = document.getElementById('safemapSubtitle');
          const pulseDot = document.getElementById('radarPulseDot');
          if (subTitle) {
            if (activeHazardsInRange.length > 0) {
              const nearest = activeHazardsInRange.sort((a, b) => a.dist - b.dist)[0];
              subTitle.innerHTML = `<span style="color:#fca5a5;font-weight:800">⚠️ PERINGATAN: Di Dekat ${nearest.point.area || 'Area Temuan'} (~${Math.round(nearest.dist)}m)</span>`;
              if (pulseDot) {
                pulseDot.style.background = '#ef4444';
                pulseDot.style.boxShadow = '0 0 10px #ef4444';
              }
            } else {
              subTitle.innerText = 'Periode Berjalan • Status Siaga';
              if (pulseDot) {
                pulseDot.style.background = '#38bdf8';
                pulseDot.style.boxShadow = '0 0 6px #38bdf8';
              }
            }
          }
        }

        function renderPoints() {
          markersLayer.clearLayers();
          radarCirclesLayer.clearLayers();

          let openCount = 0;

          allPoints.forEach(p => {
            const statusLower = String(p.status || '').toLowerCase();
            const isOpen = statusLower !== 'closed' && statusLower !== 'close' && statusLower !== 'selesai';
            if (isOpen) openCount++;

            const color = getMarkerColor(p);

            // Clickable Marker via HTML DivIcon (dengan ID unik untuk kontrol radar aktif)
            const dotHtml = `
              <div id="hazard-dot-${p.id}" onclick="window.onHazardDotClick(${p.id})" class="hazard-dot ${isOpen ? 'dot-pulse' : ''}" style="background-color: ${color};">
                <div class="hazard-inner-dot"></div>
              </div>
            `;

            const icon = L.divIcon({
              className: 'hazard-pin-wrapper',
              html: dotHtml,
              iconSize: [28, 28],
              iconAnchor: [14, 14]
            });

            const marker = L.marker([p.lat, p.lon], {
              icon: icon,
              interactive: true,
              zIndexOffset: isOpen ? 500 : 100
            }).addTo(markersLayer);

            // Tap marker langsung membuka Bottom Sheet detail temuan di Flutter
            marker.on('click', function(e) {
              if (e && e.originalEvent) {
                L.DomEvent.stopPropagation(e);
              }
              window.onHazardDotClick(p.id);
            });
          });

          // Update header counter
          const badge = document.getElementById('badgeOpenCount');
          if (badge) {
            badge.innerText = openCount + ' Belum Close';
            badge.style.display = openCount > 0 ? 'inline-block' : 'none';
          }

          // Sinkronisasi status radar berdasarkan koordinat user saat ini
          updateRadarZones();
        }

        window.updateHazardStatus = function(id, newStatus, perbaikan) {
          allPoints.forEach(p => {
            if (p.id == id) {
              p.status = newStatus;
              if (perbaikan) p.perbaikan = perbaikan;
            }
          });
          renderPoints();
        };

        window.setUserLocation = function(lat, lng, accuracy) {
          userCoordinates = [lat, lng];
          if (userMarker) map.removeLayer(userMarker);
          if (userAccuracyCircle) map.removeLayer(userAccuracyCircle);

          const icon = L.divIcon({
            className: '',
            html: '<div class="user-marker-pulse"><span style="font-size:14px">📍</span></div>',
            iconSize: [30, 30],
            iconAnchor: [15, 15]
          });

          userAccuracyCircle = L.circle(userCoordinates, {
            radius: Math.max(accuracy || 10, 10),
            color: '#2563eb',
            weight: 1,
            fillColor: '#60a5fa',
            fillOpacity: .12
          }).addTo(map);

          userMarker = L.marker(userCoordinates, { icon: icon, zIndexOffset: 1000 }).addTo(map);

          // PANDANGAN LANGSUNG OTOMATIS KE POSISI SAYA (SATELIT ZOOM 17)
          if (!hasCenteredOnUser) {
            hasCenteredOnUser = true;
            map.setView(userCoordinates, 17);
          }

          // Evaluasi radar 20m: Aktifkan lingkaran dan denyut hanya jika berada di area temuan
          updateRadarZones();

          // Kirim event proximity vibration bridge jika berada dalam radius 20 meter dari temuan Open
          const userLatLng = L.latLng(lat, lng);
          allPoints.forEach(p => {
            const statusLower = String(p.status || '').toLowerCase();
            const isOpen = statusLower !== 'closed' && statusLower !== 'close' && statusLower !== 'selesai';
            if (isOpen && p.lat && p.lon) {
              const dist = userLatLng.distanceTo(L.latLng(p.lat, p.lon));
              if (dist <= 20.0) {
                postBridgeMessage({
                  type: 'NEARBY_HAZARD',
                  id: p.id,
                  title: p.detail || 'Temuan Hazard Terdekat',
                  area: p.area || 'Area Tambang',
                  distance: dist
                });
              }
            }
          });
        };

        window.updateSafeMapPoints = function(hazards) {
          if (Array.isArray(hazards) && hazards.length > 0) {
            allPoints = hazards;
            renderPoints();
          }
        };

        document.getElementById('btnLocate').addEventListener('click', function() {
          if (userCoordinates) {
            map.flyTo(userCoordinates, 17, { animate: true, duration: 0.6 });
            if (userMarker) setTimeout(() => userMarker.openPopup(), 650);
          } else {
            postBridgeMessage({ type: 'REQUEST_LOCATION' });
          }
        });

        renderPoints();
        setTimeout(() => map.invalidateSize(), 300);
      </script>
    </body>
    </html>
    '''
    .replaceAll('__INIT_LAT__', initLat)
    .replaceAll('__INIT_LNG__', initLng)
    .replaceAll('__INIT_ZOOM__', initZoom);

    return html;
  }

  // 6. Ringkasan Kinerja K3 Tambang (Operational Safety Pulse)
  Widget _buildSafetyPerformancePulse() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: Color(0xFF0F172A)),
              SizedBox(width: 6),
              Text(
                'Status Keselamatan Operasional',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                  borderColor: const Color(0xFFA7F3D0),
                  title: 'LTI-FREE',
                  value: '1,428 Hari',
                  subtitle: 'Zero Fatality',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.task_alt_rounded,
                  iconColor: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFF0F9FF),
                  borderColor: const Color(0xFFBAE6FD),
                  title: 'RESOLUSI',
                  value: '98.4%',
                  subtitle: 'Bahaya Tertangani',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.alarm_on_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF5F3FF),
                  borderColor: const Color(0xFFDDD6FE),
                  title: 'MANHOURS',
                  value: '4.8M Jam',
                  subtitle: 'Kerja Selamat',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // 7. Pusat Tanggap Darurat K3 (Emergency Response Team)
  Widget _buildEmergencyResponseCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE11D48).withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pusat Tanggap Darurat Tambang (ERT)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF881337),
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Radio Ch. 16 • Posko Rescue & Klinik Tambang 24/7',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9F1239),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: const Color(0xFFFDA4AF).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _showEmergencyContactSheet(context);
                    },
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                    label: const Text('Kontak Darurat ERT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _showSafetyGoldenRules(context);
                    },
                    icon: const Icon(Icons.shield_rounded, size: 16),
                    label: const Text('6 Golden Rules'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9F1239),
                      side: const BorderSide(color: Color(0xFFFB7185)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Kontak Darurat Tambang (ERT)',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildEmergencyItem(
                title: 'Radio Emergency ERT',
                detail: 'Channel 16 Tambang (Frekuensi Utama Darurat)',
                icon: Icons.radio_rounded,
                color: const Color(0xFFE11D48),
              ),
              const SizedBox(height: 10),
              _buildEmergencyItem(
                title: 'Klinik & Tim Medis Tambang',
                detail: 'Posko 1 Tambang • Dokter & Paramedis Siaga 24 Jam',
                icon: Icons.local_hospital_rounded,
                color: const Color(0xFF0284C7),
              ),
              const SizedBox(height: 10),
              _buildEmergencyItem(
                title: 'Fire & Rescue ERT',
                detail: 'Gedung K3 & Rescue PT Indexim Coalindo',
                icon: Icons.fire_truck_rounded,
                color: const Color(0xFFD97706),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmergencyItem({
    required String title,
    required String detail,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSafetyGoldenRules(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFF0D9488), size: 26),
                  SizedBox(width: 10),
                  Text(
                    '6 Golden Mining Safety Rules',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildRuleRow('1', 'Fit To Work & Istirahat Cukup sebelum mulai shift.'),
              _buildRuleRow('2', 'Wajib P2H unit & sarana sebelum dioperasikan.'),
              _buildRuleRow('3', 'Gunakan APD lengkap sesuai standar area operasional.'),
              _buildRuleRow('4', 'Jaga jarak aman & patuhi batas kecepatan hauling.'),
              _buildRuleRow('5', 'Wajib pasang LOTO saat isolasi atau perbaikan unit.'),
              _buildRuleRow('6', 'Lakukan S.T.O.P jika menemukan kondisi tidak aman.'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Saya Mengerti & Berkomitmen', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRuleRow(String number, String rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D9488),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rule,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 8. Komitmen Keselamatan Tambang (Pesan Motivasi)
  Widget _buildSafetyCommitmentCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFF43F5E),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bekerja Selamat, Pulang Sehat',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Keluarga Anda menanti di rumah dengan senyuman. Selalu patuhi prosedur & laporkan setiap bahaya.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 9. Enterprise Footer
  Widget _buildEnterpriseFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Indexsafe Cloud Active • Real-time Safety Network',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_profile?.company ?? 'PT INDEXIM COALINDO'} © 2026 • Keselamatan Adalah Prioritas',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // Incident & Safety Banner Carousel on Home
  Widget _buildHomeBannerSection() {
    if (_homeBanners.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/header-home.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          Container(
            height: 148,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
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
                    color: isCurrent ? const Color(0xFF155EEF) : const Color(0xFFCBD5E1),
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
            // Background image / gradient
            if (imgUrl != null)
              Image.network(
                imgUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildBannerFallbackBg(catColor),
              )
            else
              _buildBannerFallbackBg(catColor),

            // Vignette gradient
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

            // Content
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFFEF4444)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              banner.lokasi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (banner.rawTanggal != null && banner.rawTanggal!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            const SizedBox(width: 6),
                            Text(
                              banner.rawTanggal!.split(' ').first,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildBannerFallbackBg(Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.8),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.shield_outlined, size: 60, color: Colors.white.withValues(alpha: 0.1)),
      ),
    );
  }
}

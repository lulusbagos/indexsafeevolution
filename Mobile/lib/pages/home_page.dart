import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/popup_ad_service.dart';
import '../services/security_check_service.dart';
import '../widgets/roster_prompt_dialog.dart';
import '../widgets/web_campaign_dialog.dart';
import '../services/preference.dart';
import '../utils/globals.dart' as globals;
import 'dashboard_page.dart';
import 'hazard/hazard_create_page.dart';
import 'profile_page.dart';
import 'safety_updates_page.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  int _currentPage = (globals.currentPage == 2) ? 0 : globals.currentPage;
  late int _previousPage = _currentPage;

  // Dedicated hardware-synchronized AnimationController for floating navbar slide & fade
  late final AnimationController _navAnimCtrl;
  late final Animation<Offset> _navSlideAnim;
  late final Animation<double> _navFadeAnim;

  // Ultra-smooth, lightweight directional page transition controllers (ke kiri & ke kanan)
  late final AnimationController _pageTransitionCtrl;
  late final Animation<double> _pageCurvedAnim;
  bool _isPageTransitioning = false;
  bool _isForward = true;

  // State-retained page instances: prevent re-renders, re-fetching API, and loss of scroll position
  final Widget _dashboardView = const DashboardPage();
  final Widget _safetyUpdatesView = const SafetyUpdatesPage();
  final Widget _profileView = const ProfilePage();


  Timer? _hideNavTimer;
  ImageProvider? _navbarProfileImage;
  Timer? _securityCheckTimer;
  StreamSubscription? _connectivitySub;

  @override
  void initState() {
    super.initState();

    _navAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 320),
      value: 1.0,
    );

    _navSlideAnim = Tween<Offset>(
      begin: const Offset(0, 1.45),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _navAnimCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    ));

    _navFadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _navAnimCtrl,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
      reverseCurve: const Interval(0.15, 1.0, curve: Curves.easeIn),
    ));

    // Page transition controller (280ms easeOutCubic)
    _pageTransitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _pageCurvedAnim = CurvedAnimation(
      parent: _pageTransitionCtrl,
      curve: Curves.easeOutCubic,
    );

    _pageTransitionCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _previousPage = _currentPage;
            _isPageTransitioning = false;
          });
        }
      }
    });

    _loadNavbarProfilePhoto();
    PreferenceService.profilePhotoNotifier.addListener(_onProfilePhotoChanged);
    PreferenceService.notifCountNotifier.addListener(_onNotifCountChanged);
    WidgetsBinding.instance.addObserver(this);
    _initSecurityWatcher();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bgToken', _api.getToken);
      await prefs.setInt('bgProfile', (_profile?.id ?? 0));
      await prefs.setString('bgNik', (_profile?.noNik ?? ''));

      // Tampilkan iklan popup jika ada dari backend (1 hari sekali)
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 700), () async {
          if (!mounted) return;
          try {
            await PopupAdService.checkAndShowPopupAd(context);
          } catch (_) {}

          // Cek dan tampilkan pop up pengaturan roster jika belum disetting
          if (!mounted) return;
          try {
            await RosterPromptDialog.checkAndPromptRoster(context);
          } catch (_) {}

          if (!mounted) return;
          try {
            String userNik = _profile?.noNik?.trim() ?? '';
            if (userNik.isEmpty) {
              userNik = PreferenceService.getOfflineNik() ?? '';
            }
            debugPrint('[HomePage] Checking WebCampaign for NIK: $userNik');
            await WebCampaignDialog.checkAndShow(
              context,
              nik: userNik,
              nama: _profile?.namaLengkap ?? '',
              depart: _profile?.depart ?? '',
            );
          } catch (_) {}
        });
      }
    });
  }

  @override
  void dispose() {
    _hideNavTimer?.cancel();
    _navAnimCtrl.dispose();
    _pageTransitionCtrl.dispose();
    PreferenceService.profilePhotoNotifier.removeListener(_onProfilePhotoChanged);
    PreferenceService.notifCountNotifier.removeListener(_onNotifCountChanged);
    WidgetsBinding.instance.removeObserver(this);
    _securityCheckTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _onNotifCountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !SecurityCheckService.isDialogOpen) {
      SecurityCheckService.checkAndShowIfViolation(context);
    }
  }

  void _initSecurityWatcher() {
    // 1. Cek keamanan pertama kali saat app dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        SecurityCheckService.checkAndShowIfViolation(context);
      }
    });

    // 2. Pantau perubahan jaringan real-time (misal user menyalakan VPN di tengah penggunaan)
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        if (results.contains(ConnectivityResult.vpn) && mounted) {
          SecurityCheckService.checkAndShowIfViolation(context);
        }
      });
    } catch (_) {}

    // 3. Polling berkala setiap 5 detik untuk mendeteksi Fake GPS atau VPN yang aktif di background
    _securityCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || SecurityCheckService.isDialogOpen) return;
      final status = await SecurityCheckService.instance.runFullAudit();
      if (status.hasViolation && mounted) {
        SecurityCheckService.checkAndShowIfViolation(context);
      }
    });
  }

  void _onProfilePhotoChanged() {
    _loadNavbarProfilePhoto(PreferenceService.profilePhotoNotifier.value);
  }

  Future<void> _loadNavbarProfilePhoto([String? specificFoto]) async {
    try {
      final foto = specificFoto ?? PreferenceService.getProfile()?.foto;
      if (foto == null || foto.trim().isEmpty) {
        if (mounted) setState(() => _navbarProfileImage = null);
        return;
      }

      if (foto.startsWith('http://') || foto.startsWith('https://')) {
        if (mounted) setState(() => _navbarProfileImage = NetworkImage(foto));
        return;
      }

      final localFile = File(foto);
      if (localFile.existsSync()) {
        if (mounted) setState(() => _navbarProfileImage = FileImage(localFile));
        return;
      }

      final tempDir = (await getTemporaryDirectory()).path;
      final tempFile = File('$tempDir/$foto');
      if (tempFile.existsSync()) {
        if (mounted) setState(() => _navbarProfileImage = FileImage(tempFile));
        return;
      }

      // Download from API if not yet in cache
      await _api.dio.download('${_api.baseUrl}/image/$foto', tempFile.path);
      if (mounted && tempFile.existsSync()) {
        setState(() => _navbarProfileImage = FileImage(tempFile));
      }
    } catch (e) {
      debugPrint('[HomePage] Error loading navbar profile avatar: $e');
    }
  }

  void _showNavbar() {
    _hideNavTimer?.cancel();
    if (!_navAnimCtrl.isCompleted && _navAnimCtrl.status != AnimationStatus.forward) {
      _navAnimCtrl.forward();
    }
  }

  void _scheduleHideNavbar([int delayMs = 3000]) {
    _hideNavTimer?.cancel();
    _hideNavTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted && _navAnimCtrl.value > 0) {
        _navAnimCtrl.reverse();
      }
    });
  }

  void _showNavAndScheduleHide([int delayMs = 3000]) {
    _showNavbar();
    _scheduleHideNavbar(delayMs);
  }

  /// Only responds to real physical human touch scrolling on vertical axis
  /// completely ignoring horizontal banner carousels, timers, and layout rebuilds
  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isPageTransitioning) return false;
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      // dragDetails != null GUARANTEES it is user's finger dragging on screen!
      if (notification.dragDetails != null) {
        final dy = notification.scrollDelta ?? 0;
        if (dy.abs() > 0.4) {
          _showNavbar();
          _scheduleHideNavbar(3000);
        }
      }
    } else if (notification is UserScrollNotification) {
      if (notification.direction != ScrollDirection.idle) {
        _showNavbar();
      } else {
        _scheduleHideNavbar(3000);
      }
    }
    return false;
  }

  void _onTabSelected(int index) {
    debugPrint('[NAVBAR] _onTabSelected: target=$index, current=$_currentPage');
    if (index == _currentPage) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    _showNavbar();

    final forward = index > _currentPage;
    setState(() {
      _isForward = forward;
      _previousPage = _currentPage;
      _currentPage = index;
      globals.currentPage = index;
      _isPageTransitioning = true;
    });

    _pageTransitionCtrl.forward(from: 0.0);
  }


  Future<bool> _showBackDialog() async {
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Keluar dari Aplikasi?'),
            content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batalkan', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () => exit(0),
                child: const Text('Ya, Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _showBackDialog();
      },
      child: Scaffold(
        extendBody: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: Stack(
            children: [
              // 1. Pages Body with smooth left/right directional transition and state preservation
              Positioned.fill(
                child: _buildPagesBody(),
              ),

              // 2. Gesture tap edge detection at bottom to reveal navbar if hidden
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 38,
                child: AnimatedBuilder(
                  animation: _navAnimCtrl,
                  builder: (context, _) {
                    return IgnorePointer(
                      ignoring: _navAnimCtrl.value > 0.15,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _showNavAndScheduleHide(3500),
                        onVerticalDragUpdate: (_) => _showNavAndScheduleHide(3500),
                      ),
                    );
                  },
                ),
              ),

              // 3. Floating Navbar Layer - ALWAYS ON TOP (Highest Z-index)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildAnimatedFloatingNavBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagesBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildTabWrapper(0, _dashboardView),
        _buildTabWrapper(1, _safetyUpdatesView),
        _buildTabWrapper(3, _buildScanView()),
        _buildTabWrapper(4, _profileView),
      ],
    );
  }

  Widget _buildScanView() {
    // Only mount ScanPage when active or transitioning to avoid holding camera hardware in background
    if (_currentPage == 3 || _previousPage == 3) {
      return const ScanPage();
    }
    return const SizedBox.shrink();
  }

  Widget _buildTabWrapper(int tabIndex, Widget child) {
    final isCurrent = tabIndex == _currentPage;
    final isPrevious = tabIndex == _previousPage;

    // Completely inactive: offstage to preserve state with 0 render cost
    if (!isCurrent && (!isPrevious || !_isPageTransitioning)) {
      return Offstage(
        offstage: true,
        child: child,
      );
    }

    // Currently active and idle
    if (isCurrent && !_isPageTransitioning) {
      return Offstage(
        offstage: false,
        child: child,
      );
    }

    // Entering tab transition (ke kiri / ke kanan)
    if (isCurrent && _isPageTransitioning) {
      final inBegin = _isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
      return AnimatedBuilder(
        animation: _pageCurvedAnim,
        builder: (context, _) {
          return SlideTransition(
            position: Tween<Offset>(begin: inBegin, end: Offset.zero).animate(_pageCurvedAnim),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.1, end: 1.0).animate(_pageCurvedAnim),
              child: child,
            ),
          );
        },
      );
    }

    // Exiting tab transition (ke kiri / ke kanan)
    if (isPrevious && _isPageTransitioning) {
      final outEnd = _isForward ? const Offset(-0.25, 0.0) : const Offset(0.25, 0.0);
      return AnimatedBuilder(
        animation: _pageCurvedAnim,
        builder: (context, _) {
          return SlideTransition(
            position: Tween<Offset>(begin: Offset.zero, end: outEnd).animate(_pageCurvedAnim),
            child: FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                CurvedAnimation(
                  parent: _pageTransitionCtrl,
                  curve: const Interval(0.0, 0.70, curve: Curves.easeIn),
                ),
              ),
              child: child,
            ),
          );
        },
      );
    }

    return Offstage(offstage: true, child: child);
  }

  Widget _buildAnimatedFloatingNavBar() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomMargin = bottomInset > 0 ? bottomInset + 8.0 : 16.0;

    return SlideTransition(
      position: _navSlideAnim,
      child: FadeTransition(
        opacity: _navFadeAnim,
        child: AnimatedBuilder(
          animation: _navAnimCtrl,
          builder: (context, child) {
            return IgnorePointer(
              ignoring: _navAnimCtrl.value < 0.15,
              child: child,
            );
          },
          child: Listener(
            onPointerDown: (_) => _hideNavTimer?.cancel(),
            onPointerUp: (_) => _scheduleHideNavbar(3000),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomMargin,
              ),
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final totalWidth = constraints.maxWidth;
                        const centerBtnWidth = 58.0;
                        final itemWidth = (totalWidth - centerBtnWidth) / 4.0;
                        const indWidth = 48.0;
                        const indHeight = 32.0;

                        double getIndicatorLeft(int index) {
                          switch (index) {
                            case 0:
                              return (itemWidth - indWidth) / 2.0;
                            case 1:
                              return itemWidth + (itemWidth - indWidth) / 2.0;
                            case 3:
                              return (2.0 * itemWidth) + centerBtnWidth + (itemWidth - indWidth) / 2.0;
                            case 4:
                              return (3.0 * itemWidth) + centerBtnWidth + (itemWidth - indWidth) / 2.0;
                            default:
                              return (itemWidth - indWidth) / 2.0;
                          }
                        }

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Sliding Pill Indicator ke kiri kanannya!
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              left: getIndicatorLeft(_currentPage),
                              top: 5.0,
                              width: indWidth,
                              height: indHeight,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFBFDBFE),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                              // 2. Interactive Navigation Items
                              Row(
                                children: [
                                  // 1. Beranda
                                  Expanded(
                                    child: _bottomItem(
                                      index: 0,
                                      activeIcon: Icons.home_rounded,
                                      inactiveIcon: Icons.home_outlined,
                                      label: 'Beranda',
                                    ),
                                  ),

                                  // 2. Safety Updates
                                  Expanded(
                                    child: _bottomItem(
                                      index: 1,
                                      activeIcon: Icons.health_and_safety_rounded,
                                      inactiveIcon: Icons.health_and_safety_outlined,
                                      label: 'Safety Updates',
                                    ),
                                  ),

                                  // 3. Center Quick Hazard Action Button
                                  _centerHazardButton(),

                                  // 4. Scan
                                  Expanded(
                                    child: _bottomItem(
                                      index: 3,
                                      activeIcon: Icons.qr_code_scanner_rounded,
                                      inactiveIcon: Icons.qr_code_scanner_rounded,
                                      label: 'Scan',
                                    ),
                                  ),

                                  // 5. Profil (dengan foto avatar jika sudah diupload)
                                  Expanded(
                                    child: _bottomItem(
                                      index: 4,
                                      activeIcon: Icons.person_rounded,
                                      inactiveIcon: Icons.person_outline_rounded,
                                      label: 'Profil',
                                      isProfileTab: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerHazardButton() {
    return Semantics(
      button: true,
      label: 'Quick Hazard',
      child: InkWell(
        onTap: _openQuickHazard,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: 50,
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/quick-hazard.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _bottomItem({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    bool isProfileTab = false,
  }) {
    final selected = _currentPage == index;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final activeColor = primaryColor;
    const inactiveColor = Color(0xFF64748B);
    final int notifCount = PreferenceService.getNotif();
    final bool showBadge = index == 1 && notifCount > 0;

    return InkWell(
      onTap: () => _onTabSelected(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        height: 58,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 32,
            child: Center(
              child: AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: (isProfileTab && _navbarProfileImage != null)
                    ? Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? activeColor : const Color(0xFFCBD5E1),
                            width: selected ? 1.8 : 1.0,
                          ),
                        ),
                        child: ClipOval(
                          child: Image(
                            image: _navbarProfileImage!,
                            width: 22,
                            height: 22,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              selected ? activeIcon : inactiveIcon,
                              size: 21,
                              color: selected ? activeColor : inactiveColor,
                            ),
                          ),
                        ),
                      )
                    : Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            selected ? activeIcon : inactiveIcon,
                            size: 21,
                            color: selected ? activeColor : inactiveColor,
                          ),
                          if (showBadge)
                            Positioned(
                              right: -5,
                              top: -2,
                              child: Container(
                                constraints: const BoxConstraints(
                                    minWidth: 14, minHeight: 14),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                                child: Text(
                                  notifCount > 99 ? '99+' : '$notifCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 1),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            style: TextStyle(
              color: selected ? activeColor : inactiveColor,
              fontSize: 9.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: -0.2,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _openQuickHazard() {
    _showNavAndScheduleHide(3000);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HazardCreatePage()),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';
import '../services/popup_ad_service.dart';
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

class _HomePageState extends State<HomePage> {
  final _pageCtrl = PageController(initialPage: globals.currentPage);
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  int _currentPage = globals.currentPage;

  // Auto-hide & scroll-reveal navbar state
  bool _isNavVisible = false;
  Timer? _hideNavTimer;
  ImageProvider? _navbarProfileImage;

  @override
  void initState() {
    super.initState();

    _loadNavbarProfilePhoto();
    PreferenceService.profilePhotoNotifier.addListener(_onProfilePhotoChanged);

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
    PreferenceService.profilePhotoNotifier.removeListener(_onProfilePhotoChanged);
    _pageCtrl.dispose();
    super.dispose();
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

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final dy = notification.scrollDelta ?? 0;
      if (dy.abs() > 0.8) {
        _showNavAndScheduleHide();
      }
    } else if (notification is ScrollStartNotification) {
      if (notification.metrics.axis == Axis.vertical) {
        _showNavAndScheduleHide();
      }
    }
    return false;
  }

  void _showNavAndScheduleHide([int durationMs = 2800]) {
    _hideNavTimer?.cancel();
    if (!_isNavVisible) {
      if (mounted) {
        setState(() => _isNavVisible = true);
      }
    }
    _hideNavTimer = Timer(Duration(milliseconds: durationMs), () {
      if (mounted && _isNavVisible) {
        setState(() => _isNavVisible = false);
      }
    });
  }

  Future<bool> _showBackDialog() async {
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keluar dari Aplikasi?'),
            content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => exit(0),
                child: const Text('Ya, Keluar'),
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
              // 1. Pages Body
              Positioned.fill(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                      globals.currentPage = page;
                    });
                    _showNavAndScheduleHide(3000);
                  },
                  children: const [
                    DashboardPage(),
                    SafetyUpdatesPage(),
                    SizedBox.shrink(),
                    ScanPage(),
                    ProfilePage(),
                  ],
                ),
              ),

              // 2. Gesture tap edge detection at bottom to reveal navbar if hidden
              if (!_isNavVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 36,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _showNavAndScheduleHide(3500),
                    onVerticalDragUpdate: (_) => _showNavAndScheduleHide(3500),
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

  Widget _buildAnimatedFloatingNavBar() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomMargin = bottomInset > 0 ? bottomInset + 8.0 : 16.0;

    return AnimatedSlide(
      offset: _isNavVisible ? Offset.zero : const Offset(0, 1.4),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _isNavVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: IgnorePointer(
          ignoring: !_isNavVisible,
          child: Listener(
            onPointerDown: (_) => _hideNavTimer?.cancel(),
            onPointerUp: (_) {
              _hideNavTimer?.cancel();
              _hideNavTimer = Timer(const Duration(milliseconds: 2800), () {
                if (mounted && _isNavVisible) {
                  setState(() => _isNavVisible = false);
                }
              });
            },
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
                      color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.94),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
            ),
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

    return InkWell(
      onTap: () {
        _showNavAndScheduleHide(3000);
        _pageCtrl.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isProfileTab && _navbarProfileImage != null ? 8 : 12,
              vertical: isProfileTab && _navbarProfileImage != null ? 3 : 3,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFEFF6FF)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFFBFDBFE)
                    : Colors.transparent,
                width: 1.0,
              ),
            ),
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
                : Icon(
                    selected ? activeIcon : inactiveIcon,
                    size: 21,
                    color: selected ? activeColor : inactiveColor,
                  ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? activeColor : inactiveColor,
              fontSize: 9.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
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

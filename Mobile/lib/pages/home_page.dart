import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();

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
    /** */

    super.dispose();
  }

  void _showBackDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Keluar Aplikasi'),
          content: const Text(
            'Apakah anda akan keluar aplikasi?',
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Ok'),
              onPressed: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (Platform.isAndroid) {
                    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                  } else if (Platform.isIOS) {
                    exit(0);
                  }
                });
              },
            ),
          ],
        );
      },
    );
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
        body: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (page) {
            setState(() {
              _currentPage = page;
              globals.currentPage = page;
            });
          },
          children: const [
            DashboardPage(),
            SafetyUpdatesPage(),
            SizedBox.shrink(),
            ScanPage(),
            ProfilePage(),
          ],
        ),
        extendBody: true,
        bottomNavigationBar: bottomNavBar(),
        // floatingActionButton: FloatingActionButton(
        //   elevation: 12,
        //   shape: const CircleBorder(),
        //   onPressed: () {
        //     Navigator.push(
        //       context,
        //       MaterialPageRoute(
        //         builder: (context) => const HazardFormPage(),
        //       ),
        //     );
        //   },
        //   tooltip: 'Quick',
        //   backgroundColor: Theme.of(context).colorScheme.primary,
        //   child: Image.asset(
        //     'assets/images/quick-hazard.png',
        //     height: 72,
        //     fit: BoxFit.cover,
        //   ),
        // ),
        // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        // floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      ),
    );
  }

  Widget bottomNavBar() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomMargin = bottomInset > 0 ? bottomInset + 4.0 : 14.0;

    return Padding(
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

                  // 5. Profil
                  Expanded(
                    child: _bottomItem(
                      index: 4,
                      activeIcon: Icons.person_rounded,
                      inactiveIcon: Icons.person_outline_rounded,
                      label: 'Profil',
                    ),
                  ),
                ],
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
  }) {
    final selected = _currentPage == index;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final activeColor = primaryColor;
    const inactiveColor = Color(0xFF64748B);

    return InkWell(
      onTap: () {
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
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
            child: Icon(
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HazardCreatePage()),
    );
  }
}

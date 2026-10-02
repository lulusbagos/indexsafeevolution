import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final centerGap = screenWidth < 360 ? 38.0 : 48.0;

    return SizedBox(
      height: 100 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 18,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: const Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: Row(
                  children: [
                    Expanded(
                      child: _bottomItem(
                        index: 0,
                        icon: Icons.home_rounded,
                        label: 'Beranda',
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _bottomItem(
                          index: 1,
                          icon: Icons.health_and_safety_rounded,
                          label: 'Updates',
                        ),
                      ),
                    ),
                    SizedBox(width: centerGap), // Responsive gap for center Quick Hazard FAB
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _bottomItem(
                          index: 3,
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Scan',
                        ),
                      ),
                    ),
                    Expanded(
                      child: _bottomItem(
                        index: 4,
                        icon: Icons.person_rounded,
                        label: 'Profil',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                button: true,
                label: 'Quick Hazard',
                child: InkWell(
                  onTap: _openQuickHazard,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 62,
                    height: 62,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF0284C7).withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/quick-hazard.png',
                      fit: BoxFit.contain,
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

  Widget _bottomItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _currentPage == index;
    final color = selected
        ? const Color(0xFF0D9488) // Brand Teal
        : const Color(0xFF64748B);

    return InkWell(
      onTap: () {
        if (_currentPage == index) return;
        HapticFeedback.selectionClick();
        if ((index - _currentPage).abs() > 1) {
          _pageCtrl.jumpToPage(index);
        } else {
          _pageCtrl.animateToPage(
            index,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFCCFBF1).withValues(alpha: 0.6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 23,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
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

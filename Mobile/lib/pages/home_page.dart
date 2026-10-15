import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';
import '../services/preference.dart';
import '../utils/globals.dart' as globals;
import 'dashboard_page.dart';
import 'hazard/hazard_form_page.dart';
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
    return SizedBox(
      height: 122,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 27,
            child: Container(
              decoration: BoxDecoration(
                color:
                    Theme.of(context).bottomAppBarTheme.color ?? Colors.white,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A0F172A),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
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
                      child: Transform.translate(
                        offset: const Offset(-8, 0),
                        child: _bottomItem(
                          index: 1,
                          icon: Icons.health_and_safety_rounded,
                          label: 'Safety Updates',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(8, 0),
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
                    width: 70,
                    height: 70,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x401D4ED8),
                          blurRadius: 16,
                          offset: Offset(0, 7),
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
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF667085);

    return InkWell(
      onTap: () {
        _pageCtrl.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 27, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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
      MaterialPageRoute(builder: (context) => const HazardFormPage()),
    );
  }
}

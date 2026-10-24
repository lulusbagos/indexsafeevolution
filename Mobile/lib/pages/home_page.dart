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
      await prefs.setString('bgNik', (_profile?.noNik ?? ''));
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
    final navHeight = 92.0 + (bottomInset > 0 ? bottomInset : 8.0);
    final bgColor = Theme.of(context).bottomAppBarTheme.color ?? Colors.white;

    return SizedBox(
      height: navHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Sculpted Concave Notched Background
          Positioned.fill(
            top: 18,
            child: CustomPaint(
              painter: NotchedNavBarPainter(
                color: bgColor,
                notchRadius: 37.0,
                cornerRadius: 24.0,
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
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

                      // 3. Center Notch Spacer
                      const SizedBox(width: 68),

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

          // Center Quick Hazard Button nestled seamlessly into the Notch
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
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Color(0xFFF8FAFC),
                          Color(0xFFE2E8F0),
                        ],
                      ),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        // Deep floating 3D ambient glow
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: .44),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        // Directional drop shadow
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: .18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                        // Top rim specular light (3D dome shine)
                        BoxShadow(
                          color: Colors.white.withValues(alpha: .9),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
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
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
  }) {
    final selected = _currentPage == index;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final color = selected ? primaryColor : const Color(0xFF64748B);

    return InkWell(
      onTap: () {
        _pageCtrl.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
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
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? primaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              selected ? activeIcon : inactiveIcon,
              size: 23,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 10,
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

/// Custom Sculpted Notched Navbar Painter with 3D Silhouette & Specular Rim Light
class NotchedNavBarPainter extends CustomPainter {
  final Color color;
  final double notchRadius;
  final double cornerRadius;

  NotchedNavBarPainter({
    required this.color,
    this.notchRadius = 37.0,
    this.cornerRadius = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final path = Path();

    // Start top-left
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Straight line to start of notch
    final notchStart = cx - notchRadius - 12;
    final notchEnd = cx + notchRadius + 12;
    path.lineTo(notchStart, 0);

    // Smooth organic concave curve around the center FAB
    path.cubicTo(
      cx - notchRadius, 0,
      cx - notchRadius + 4, notchRadius * 0.72,
      cx, notchRadius * 0.72,
    );
    path.cubicTo(
      cx + notchRadius - 4, notchRadius * 0.72,
      cx + notchRadius, 0,
      notchEnd, 0,
    );

    // Straight line to top-right
    path.lineTo(w - cornerRadius, 0);
    path.quadraticBezierTo(w, 0, w, cornerRadius);

    // Bottom and left edges
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // 1. Multi-tier 3D Ambient & Directional Elevation Shadows
    canvas.drawShadow(
      path,
      const Color(0xFF0F172A).withValues(alpha: 0.18),
      18.0,
      true,
    );
    canvas.drawShadow(
      path,
      const Color(0xFF0284C7).withValues(alpha: 0.12),
      8.0,
      true,
    );

    // 2. Base Fill with subtle 3D vertical depth gradient (crisp white to pearl slate)
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color,
          color.withValues(alpha: 0.98),
          const Color(0xFFF8FAFC),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, fillPaint);

    // 3. 3D Bevel Rim Light (Specular Highlight on top contoured edge)
    final topEdgePath = Path();
    topEdgePath.moveTo(0, cornerRadius);
    topEdgePath.quadraticBezierTo(0, 0, cornerRadius, 0);
    topEdgePath.lineTo(notchStart, 0);
    topEdgePath.cubicTo(
      cx - notchRadius, 0,
      cx - notchRadius + 4, notchRadius * 0.72,
      cx, notchRadius * 0.72,
    );
    topEdgePath.cubicTo(
      cx + notchRadius - 4, notchRadius * 0.72,
      cx + notchRadius, 0,
      notchEnd, 0,
    );
    topEdgePath.lineTo(w - cornerRadius, 0);
    topEdgePath.quadraticBezierTo(w, 0, w, cornerRadius);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = const LinearGradient(
        colors: [
          Color(0x22CBD5E1),
          Color(0x6694A3B8),
          Color(0xFF38BDF8), // Subtle cyan reflection near center socket
          Color(0x6694A3B8),
          Color(0x22CBD5E1),
        ],
        stops: [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, 30));
    canvas.drawPath(topEdgePath, rimPaint);

    // 4. Subtle 3D Socket Occlusion Silhouette inside the Notch Scoop
    final notchOcclusionPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.65),
        radius: 0.45,
        colors: [
          const Color(0xFF0F172A).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, notchRadius * 0.4), radius: notchRadius + 14));
    canvas.drawPath(path, notchOcclusionPaint);
  }

  @override
  bool shouldRepaint(covariant NotchedNavBarPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}

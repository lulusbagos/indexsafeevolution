import 'package:flutter/material.dart';

import '../../utils/links.dart';
import '../../utils/routers.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/top_bar.dart';

class ExtraPage extends StatefulWidget {
  const ExtraPage({super.key});

  @override
  State<ExtraPage> createState() => _ExtraPageState();
}

class _ExtraPageState extends State<ExtraPage> {
  static const Map<String, ({Color bgTint, Color iconColor})> _menuColors = {
    '/sap_achievement': (bgTint: Color(0xFFEFF6FF), iconColor: Color(0xFF2563EB)),
    '/sap_league': (bgTint: Color(0xFFFFFBEB), iconColor: Color(0xFFD97706)),
    '/sap_work_roster': (bgTint: Color(0xFFF0FDFA), iconColor: Color(0xFF0D9488)),
    '/sap_quality': (bgTint: Color(0xFFF5F3FF), iconColor: Color(0xFF7C3AED)),
    '/sap_action_plan': (bgTint: Color(0xFFFFF1F2), iconColor: Color(0xFFE11D48)),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(title: 'Performance Hub'),
      body: AmbientBackground(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                itemCount: listMenuExtra.length,
                itemBuilder: (context, index) {
                  final item = listMenuExtra[index];
                  final cleanTitle = item.title.replaceAll('\n', ' ');
                  final colors = _menuColors[item.route] ??
                      (bgTint: const Color(0xFFF1F5F9), iconColor: const Color(0xFF475569));

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    elevation: 0,
                    child: InkWell(
                      onTap: () {
                        if (item.route.isNotEmpty) {
                          routePage(context, item.route, title: cleanTitle);
                        }
                      },
                      borderRadius: BorderRadius.circular(18),
                      splashColor: colors.bgTint,
                      highlightColor: colors.bgTint.withValues(alpha: 0.5),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: colors.bgTint,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: (item.image != null && item.image!.isNotEmpty)
                                  ? Image.asset(
                                      item.image!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        item.icon,
                                        color: colors.iconColor,
                                        size: 28,
                                      ),
                                    )
                                  : Icon(
                                      item.icon,
                                      color: colors.iconColor,
                                      size: 28,
                                    ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              cleanTitle,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

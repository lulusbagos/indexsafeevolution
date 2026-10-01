import 'package:flutter/material.dart';

import '../utils/enums.dart';
import '../utils/helpers.dart';

Color moduleAccentColor(Module module) {
  switch (module) {
    case Module.hazard:
      return const Color(0xFFF97316);
    case Module.observation:
      return const Color(0xFF2563EB);
    case Module.coaching:
      return const Color(0xFF7C3AED);
    case Module.inspection:
    case Module.inspectionDaily:
    case Module.inspectionWeekly:
    case Module.simama:
      return const Color(0xFF0F766E);
    case Module.p2h:
      return const Color(0xFF0284C7);
    case Module.p5m:
      return const Color(0xFF16A34A);
    case Module.safety:
      return const Color(0xFFDC2626);
    case Module.induction:
      return const Color(0xFF4F46E5);
  }
}

IconData moduleIcon(Module module) {
  switch (module) {
    case Module.hazard:
      return Icons.warning_amber_rounded;
    case Module.observation:
      return Icons.visibility_rounded;
    case Module.coaching:
      return Icons.record_voice_over_rounded;
    case Module.inspection:
    case Module.inspectionDaily:
    case Module.inspectionWeekly:
    case Module.simama:
      return Icons.fact_check_rounded;
    case Module.p2h:
      return Icons.car_repair_rounded;
    case Module.p5m:
      return Icons.health_and_safety_rounded;
    case Module.safety:
      return Icons.campaign_rounded;
    case Module.induction:
      return Icons.school_rounded;
  }
}

String moduleSubtitle(Module module) {
  switch (module) {
    case Module.hazard:
      return 'Laporkan temuan bahaya, tindak lanjut PJA, dan pantau status penanganan.';
    case Module.observation:
      return 'Catat perilaku kerja aman/tidak aman dengan detail lokasi dan bukti.';
    case Module.coaching:
      return 'Kelola sesi coaching, peserta, materi, dan evidence aktivitas.';
    case Module.inspection:
      return 'Jalankan management inspection dengan checklist dan dokumentasi lapangan.';
    case Module.inspectionDaily:
      return 'Checklist harian untuk memastikan area dan pekerjaan siap dengan aman.';
    case Module.inspectionWeekly:
      return 'Inspeksi mingguan dengan kontrol temuan dan follow up action.';
    case Module.simama:
      return 'Sidak malam management untuk kontrol kepatuhan shift malam.';
    case Module.p2h:
      return 'Pemeriksaan unit sebelum digunakan agar kendaraan aman beroperasi.';
    case Module.p5m:
      return 'Fit to Work dan P5M untuk memastikan kesiapan pekerja sebelum aktivitas.';
    case Module.safety:
      return 'Dokumentasikan safety talk dan komunikasi K3 di area kerja.';
    case Module.induction:
      return 'Kelola induction dan pemahaman dasar keselamatan pekerja.';
  }
}

class SapModuleHeader extends StatelessWidget {
  const SapModuleHeader({
    required this.module,
    this.trailing,
    super.key,
  });

  final Module module;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = moduleAccentColor(module);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, Color.lerp(accent, Colors.black, .22)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(moduleIcon(module), color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pageTitle(module),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  moduleSubtitle(module),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class SapSoftCard extends StatelessWidget {
  const SapSoftCard({
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SapStatusPill extends StatelessWidget {
  const SapStatusPill({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class SapInfoLine extends StatelessWidget {
  const SapInfoLine({
    required this.icon,
    required this.text,
    super.key,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.blueGrey.shade700,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

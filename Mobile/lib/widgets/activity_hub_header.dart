import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../pages/notif_page.dart';
import '../services/offline_sync_service.dart';
import '../utils/globals.dart' as globals;

const _ink = Color(0xFF0D2F31);
const _green = Color(0xFF0AA45A);

/// Consistent header for the SAP, OHS, and Performance Hub landing pages.
class ActivityHubHeader extends StatelessWidget {
  const ActivityHubHeader({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(children: [
          _roundButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => Navigator.maybePop(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF68757B), fontSize: 11)),
              ],
            ),
          ),
          ValueListenableBuilder<OfflineSyncState>(
            valueListenable: OfflineSyncService.instance.state,
            builder: (_, state, __) =>
                Stack(clipBehavior: Clip.none, children: [
              _roundButton(
                icon: state.isOnline
                    ? Icons.sync_rounded
                    : Icons.cloud_off_rounded,
                color: state.pendingCount > 0 || !state.isOnline
                    ? const Color(0xFFDC2626)
                    : _green,
                onTap: () => OfflineSyncService.instance.syncNow(),
              ),
              if (state.pendingCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: const Color(0xFFDC2626),
                    child: Text('${state.pendingCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 7),
          _roundButton(
              icon: Icons.notifications_none_rounded,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotifPage()))),
          const SizedBox(width: 7),
          _roundButton(
            icon: Icons.account_circle_outlined,
            onTap: () {
              globals.currentPage = 4;
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (_) => false);
            },
          ),
        ]),
      );

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = _ink,
  }) =>
      Material(
        color: const Color(0xFFF1F6F4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
              height: 40, width: 40, child: Icon(icon, color: color, size: 23)),
        ),
      );
}

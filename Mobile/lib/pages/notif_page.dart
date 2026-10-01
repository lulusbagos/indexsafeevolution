import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/notification_item_model.dart';
import '../services/api.dart';
import '../services/notification.dart';
import '../services/preference.dart';

class NotifPage extends StatefulWidget {
  const NotifPage({super.key});

  @override
  State<NotifPage> createState() => _NotifPageState();
}

class _NotifPageState extends State<NotifPage> {
  final ApiService _api = ApiService();
  bool _isLoading = false;
  List<NotificationItemModel> _notifications = [];
  String _activeFilter = 'all'; // 'all', 'unread', or 'action_pending'

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final res = await _api.getNotifications(limit: 50);
    res.fold(
      (err) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
      (data) {
        if (mounted) {
          setState(() {
            _notifications = data;
            _isLoading = false;
          });
          final unreadCount = data.where((n) => !n.isRead).length;
          final unactionedCount = data.where((n) => n.isActionRequired && !n.isActioned).length;
          PreferenceService.setNotifCounts(unread: unreadCount, unactioned: unactionedCount);
        }
      },
    );
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.lightImpact();
    setState(() {
      for (var n in _notifications) {
        n.isRead = true;
      }
    });
    final unactionedCount = _notifications.where((n) => n.isActionRequired && !n.isActioned).length;
    PreferenceService.setNotifCounts(unread: 0, unactioned: unactionedCount);
    await _api.markAllNotificationsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Semua notifikasi telah ditandai dibaca'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _markAllAsActioned() async {
    HapticFeedback.mediumImpact();
    setState(() {
      for (var n in _notifications) {
        if (n.isActionRequired) {
          n.isActioned = true;
          n.isRead = true;
        }
      }
    });
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    PreferenceService.setNotifCounts(unread: unreadCount, unactioned: 0);
    await _api.markAllNotificationsActioned();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.task_alt_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Semua temuan ditandai telah di-action!'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onNotificationTap(NotificationItemModel item) async {
    HapticFeedback.selectionClick();

    // Mark as read if currently unread
    if (!item.isRead) {
      setState(() => item.isRead = true);
      final unreadCount = _notifications.where((n) => !n.isRead).length;
      final unactionedCount = _notifications.where((n) => n.isActionRequired && !n.isActioned).length;
      PreferenceService.setNotifCounts(unread: unreadCount, unactioned: unactionedCount);
      _api.markNotificationRead(item.id);
    }

    // Directly navigate to target menu
    if (item.url != null && item.url!.isNotEmpty) {
      NotificationService.navigateToUrl(item.url!);
    }
  }

  Future<void> _toggleActionStatus(NotificationItemModel item) async {
    HapticFeedback.mediumImpact();
    setState(() {
      item.isActioned = !item.isActioned;
      if (item.isActioned) {
        item.isRead = true;
      }
    });

    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final unactionedCount = _notifications.where((n) => n.isActionRequired && !n.isActioned).length;
    PreferenceService.setNotifCounts(unread: unreadCount, unactioned: unactionedCount);

    if (item.isActioned) {
      await _api.markNotificationActioned(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tindakan untuk "${item.title}" ditandai selesai.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }


  _NotifStyle _getNotifStyle(NotificationItemModel item) {
    final type = item.notifType.toLowerCase();
    switch (type) {
      case 'timeline_like':
        return _NotifStyle(
          icon: Icons.favorite_rounded,
          iconColor: const Color(0xFFEF4444),
          bgColor: const Color(0xFFFEE2E2),
          accentColor: const Color(0xFFEF4444),
          menuLabel: 'Buka Timeline ›',
        );
      case 'timeline_comment':
        return _NotifStyle(
          icon: Icons.chat_bubble_rounded,
          iconColor: const Color(0xFF3B82F6),
          bgColor: const Color(0xFFDBEAFE),
          accentColor: const Color(0xFF3B82F6),
          menuLabel: 'Buka Komentar ›',
        );
      case 'hazard_new':
      case 'hazard_reassign':
        return _NotifStyle(
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFEA580C),
          bgColor: const Color(0xFFFFEDD5),
          accentColor: const Color(0xFFEA580C),
          menuLabel: 'Tindaklanjuti Hazard ›',
        );
      case 'inspection_new':
      case 'inspection_reassign':
        return _NotifStyle(
          icon: Icons.fact_check_rounded,
          iconColor: const Color(0xFF10B981),
          bgColor: const Color(0xFFD1FAE5),
          accentColor: const Color(0xFF10B981),
          menuLabel: 'Buka Laporan Inspeksi ›',
        );
      case 'actionplan_new':
      case 'actionplan_reassign':
        return _NotifStyle(
          icon: Icons.event_note_rounded,
          iconColor: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFFEDE9FE),
          accentColor: const Color(0xFF8B5CF6),
          menuLabel: 'Tindaklanjuti Action Plan ›',
        );
      default:
        if (item.isTemuanUrgent) {
          return _NotifStyle(
            icon: Icons.warning_rounded,
            iconColor: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEE2E2),
            accentColor: const Color(0xFFDC2626),
            menuLabel: 'Tindaklanjuti Temuan ›',
          );
        }
        return _NotifStyle(
          icon: Icons.notifications_active_rounded,
          iconColor: const Color(0xFF6366F1),
          bgColor: const Color(0xFFEEF2FF),
          accentColor: const Color(0xFF6366F1),
          menuLabel: 'Lihat Detail Menu ›',
        );
    }
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'Baru saja';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return DateFormat('d MMM yyyy, HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final unactionedCount = _notifications.where((n) => n.isActionRequired && !n.isActioned).length;

    List<NotificationItemModel> filtered;
    if (_activeFilter == 'unread') {
      filtered = _notifications.where((n) => !n.isRead).toList();
    } else if (_activeFilter == 'action_pending') {
      filtered = _notifications.where((n) => n.isActionRequired && !n.isActioned).toList();
    } else {
      filtered = _notifications;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifikasi & Temuan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Row(
              children: [
                if (unreadCount > 0)
                  Text(
                    '$unreadCount belum dibaca',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  )
                else
                  Text(
                    'Semua dibaca',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                if (unactionedCount > 0) ...[
                  Text(' • ', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  Text(
                    '$unactionedCount perlu action',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF475569)),
            onSelected: (val) {
              if (val == 'read_all') _markAllAsRead();
              if (val == 'action_all') _markAllAsActioned();
            },
            itemBuilder: (ctx) => [
              if (unreadCount > 0)
                const PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Text('Tandai Semua Dibaca', style: TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              if (unactionedCount > 0)
                const PopupMenuItem(
                  value: 'action_all',
                  child: Row(
                    children: [
                      Icon(Icons.task_alt_rounded, size: 18, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text('Selesaikan Semua Action', style: TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs (Semua, Belum Dibaca, Belum Di-Action) & Test Vibration
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Filter 1: Semua
                      _buildFilterChip(
                        label: 'Semua',
                        count: _notifications.length,
                        badgeColor: const Color(0xFF64748B),
                        isActive: _activeFilter == 'all',
                        onTap: () => setState(() => _activeFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      // Filter 2: Belum Dibaca
                      _buildFilterChip(
                        label: 'Belum Dibaca',
                        count: unreadCount,
                        badgeColor: const Color(0xFFEF4444),
                        isActive: _activeFilter == 'unread',
                        onTap: () => setState(() => _activeFilter = 'unread'),
                      ),
                      const SizedBox(width: 8),
                      // Filter 3: Belum Action / Perlu Tindakan
                      _buildFilterChip(
                        label: 'Belum Action',
                        count: unactionedCount,
                        badgeColor: const Color(0xFFF59E0B),
                        isActive: _activeFilter == 'action_pending',
                        onTap: () => setState(() => _activeFilter = 'action_pending'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Notification List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchNotifications,
              color: const Color(0xFF2563EB),
              child: _isLoading && _notifications.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildNotificationCard(filtered[index]);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required Color badgeColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: count > 0 && !isActive ? badgeColor : (isActive ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: count > 0 && !isActive ? Colors.white : (isActive ? Colors.white : const Color(0xFF475569)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItemModel item) {
    final style = _getNotifStyle(item);
    final isUnread = !item.isRead;
    final isPendingAction = item.isActionRequired && !item.isActioned;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNotificationTap(item),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isPendingAction
                ? const Color(0xFFFFFBEB)
                : (isUnread ? const Color(0xFFFFFFFF) : const Color(0xFFFAFAFA)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPendingAction
                  ? const Color(0xFFF59E0B)
                  : (isUnread ? style.accentColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
              width: isPendingAction || isUnread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isPendingAction
                        ? const Color(0xFFF59E0B)
                        : (isUnread ? style.accentColor : Colors.black))
                    .withValues(alpha: isPendingAction ? 0.08 : (isUnread ? 0.06 : 0.02)),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Unread or pending action vertical bar
                Container(
                  width: 5,
                  color: isPendingAction
                      ? const Color(0xFFF59E0B)
                      : (isUnread ? style.accentColor : Colors.transparent),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Icon Circle
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: style.bgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(style.icon, color: style.iconColor, size: 22),
                        ),
                        const SizedBox(width: 12),

                        // Title, Message, Action Status & Navigation
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top badges: Action Required / Action Done + Unread dot
                              Row(
                                children: [
                                  if (item.isActionRequired) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPendingAction
                                            ? const Color(0xFFFEF3C7)
                                            : const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isPendingAction
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF10B981),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isPendingAction
                                                ? Icons.bolt_rounded
                                                : Icons.check_circle_rounded,
                                            size: 11,
                                            color: isPendingAction
                                                ? const Color(0xFFD97706)
                                                : const Color(0xFF059669),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            isPendingAction ? 'PERLU ACTION' : 'ACTION SELESAI',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              color: isPendingAction
                                                  ? const Color(0xFFB45309)
                                                  : const Color(0xFF047857),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  const Spacer(),
                                  if (isUnread) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'BARU',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 5),

                              // Title
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isUnread || isPendingAction
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Message Body
                              Text(
                                item.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: isUnread ? const Color(0xFF334155) : Colors.grey.shade600,
                                  fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Footer Row: Relative Time & Direct Action Link
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatRelativeTime(item.createdAt),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Mark Action Button if action required
                                  if (item.isActionRequired) ...[
                                    InkWell(
                                      onTap: () => _toggleActionStatus(item),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: item.isActioned
                                              ? const Color(0xFFF1F5F9)
                                              : const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: item.isActioned
                                                ? const Color(0xFFCBD5E1)
                                                : const Color(0xFFA7F3D0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              item.isActioned
                                                  ? Icons.undo_rounded
                                                  : Icons.check_circle_outline_rounded,
                                              size: 11,
                                              color: item.isActioned
                                                  ? const Color(0xFF64748B)
                                                  : const Color(0xFF059669),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              item.isActioned ? 'Batal' : 'Tandai Selesai',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                color: item.isActioned
                                                  ? const Color(0xFF64748B)
                                                  : const Color(0xFF059669),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  // Direct Menu Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isPendingAction ? const Color(0xFFFFEDD5) : style.bgColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      style.menuLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isPendingAction ? const Color(0xFFEA580C) : style.iconColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: const Icon(
                Icons.notifications_off_rounded,
                size: 32,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada notifikasi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _activeFilter == 'unread'
                  ? 'Semua notifikasi telah Anda baca.'
                  : _activeFilter == 'action_pending'
                      ? 'Luar biasa! Tidak ada temuan K3 yang menunggu tindakan Anda.'
                      : 'Notifikasi aktivitas K3 dan penugasan temuan akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifStyle {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color accentColor;
  final String menuLabel;

  _NotifStyle({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.accentColor,
    required this.menuLabel,
  });
}

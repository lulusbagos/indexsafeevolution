class NotificationItemModel {
  final int id;
  final String title;
  final String message;
  final String? url;
  bool isRead;
  bool isActioned;
  final bool isActionRequired;
  final String notifType;
  final DateTime? createdAt;
  final String? rawCreatedAt;

  NotificationItemModel({
    required this.id,
    required this.title,
    required this.message,
    this.url,
    this.isRead = false,
    this.isActioned = false,
    this.isActionRequired = false,
    this.notifType = 'general',
    this.createdAt,
    this.rawCreatedAt,
  });

  /// Apakah ini temuan K3 / penugasan yang diarahkan ke login bersangkutan
  bool get isTemuanUrgent {
    final t = notifType.toLowerCase();
    if (t.startsWith('hazard_') ||
        t.startsWith('inspection_') ||
        t.startsWith('actionplan_')) {
      return true;
    }
    final combined = '$title $message'.toLowerCase();
    return combined.contains('temuan') ||
        combined.contains('penugasan') ||
        combined.contains('perlu mitigasi') ||
        combined.contains('tindakan') ||
        combined.contains('action plan') ||
        combined.contains('assigned') ||
        combined.contains('reassign');
  }

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    final dateStr = json['created_at']?.toString();
    if (dateStr != null && dateStr.isNotEmpty) {
      dt = DateTime.tryParse(dateStr);
    }

    final nType = json['notif_type']?.toString() ?? 'general';
    final nTitle = json['title']?.toString() ?? '';
    final nMsg = json['message']?.toString() ?? '';

    bool actionReq = json['is_action_required'] == true || json['is_action_required'] == 1;
    if (!actionReq) {
      // Auto-detect based on type or content
      final t = nType.toLowerCase();
      if (t.startsWith('hazard_') || t.startsWith('inspection_') || t.startsWith('actionplan_')) {
        actionReq = true;
      } else {
        final combined = '$nTitle $nMsg'.toLowerCase();
        actionReq = combined.contains('temuan') ||
            combined.contains('penugasan') ||
            combined.contains('tindakan') ||
            combined.contains('action plan');
      }
    }

    return NotificationItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: nTitle,
      message: nMsg,
      url: json['url']?.toString(),
      isRead: json['is_read'] == true || json['is_read'] == 1,
      isActioned: json['is_actioned'] == true || json['is_actioned'] == 1,
      isActionRequired: actionReq,
      notifType: nType,
      createdAt: dt,
      rawCreatedAt: dateStr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'url': url,
      'is_read': isRead,
      'is_actioned': isActioned,
      'is_action_required': isActionRequired,
      'notif_type': notifType,
      'created_at': rawCreatedAt,
    };
  }
}

import 'package:flutter/material.dart';

class SapQualityDashboardModel {
  final String nik;
  final String nama;
  final String departemen;
  final String perusahaan;
  final int? selectedYear;
  final int? selectedMonth;
  final int totalAllSap;
  final int totalAssessed;
  final int auditedBySupervisorCount;
  final int kualitasBaik;
  final int kejarTarget;
  final double goodPercentage;
  final double targetPercentage;
  final double averageRating;
  final double qualityScorePercent;
  final int star5;
  final int star4;
  final int star3;
  final int star2;
  final int star1;
  final List<SapQualityModuleStatModel> moduleStats;
  final List<SapQualityItemModel> items;

  SapQualityDashboardModel({
    required this.nik,
    required this.nama,
    required this.departemen,
    required this.perusahaan,
    this.selectedYear,
    this.selectedMonth,
    required this.totalAllSap,
    required this.totalAssessed,
    required this.auditedBySupervisorCount,
    required this.kualitasBaik,
    required this.kejarTarget,
    required this.goodPercentage,
    required this.targetPercentage,
    required this.averageRating,
    required this.qualityScorePercent,
    required this.star5,
    required this.star4,
    required this.star3,
    required this.star2,
    required this.star1,
    required this.moduleStats,
    required this.items,
  });

  factory SapQualityDashboardModel.fromJson(Map<String, dynamic> json) {
    return SapQualityDashboardModel(
      nik: json['nik']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      departemen: json['departemen']?.toString() ?? 'GENERAL',
      perusahaan: json['perusahaan']?.toString() ?? 'PT INDEXIM COALINDO',
      selectedYear: json['selectedYear'] as int?,
      selectedMonth: json['selectedMonth'] as int?,
      totalAllSap: (json['totalAllSap'] as num?)?.toInt() ?? 0,
      totalAssessed: (json['totalAssessed'] as num?)?.toInt() ?? 0,
      auditedBySupervisorCount: (json['auditedBySupervisorCount'] as num?)?.toInt() ?? 0,
      kualitasBaik: (json['kualitasBaik'] as num?)?.toInt() ?? 0,
      kejarTarget: (json['kejarTarget'] as num?)?.toInt() ?? 0,
      goodPercentage: (json['goodPercentage'] as num?)?.toDouble() ?? 0.0,
      targetPercentage: (json['targetPercentage'] as num?)?.toDouble() ?? 0.0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      qualityScorePercent: (json['qualityScorePercent'] as num?)?.toDouble() ?? 0.0,
      star5: (json['star5'] as num?)?.toInt() ?? 0,
      star4: (json['star4'] as num?)?.toInt() ?? 0,
      star3: (json['star3'] as num?)?.toInt() ?? 0,
      star2: (json['star2'] as num?)?.toInt() ?? 0,
      star1: (json['star1'] as num?)?.toInt() ?? 0,
      moduleStats: (json['moduleStats'] as List?)
              ?.map((e) => SapQualityModuleStatModel.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      items: (json['items'] as List?)
              ?.map((e) => SapQualityItemModel.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }
}

class SapQualityModuleStatModel {
  final String key;
  final String name;
  final int total;
  final int assessed;
  final double averageRating;
  final String themeColor;
  final String icon;
  final int star1;
  final int star2;
  final int star3;
  final int star4;
  final int star5;

  SapQualityModuleStatModel({
    required this.key,
    required this.name,
    required this.total,
    required this.assessed,
    required this.averageRating,
    required this.themeColor,
    required this.icon,
    required this.star1,
    required this.star2,
    required this.star3,
    required this.star4,
    required this.star5,
  });

  factory SapQualityModuleStatModel.fromJson(Map<String, dynamic> json) {
    return SapQualityModuleStatModel(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      assessed: (json['assessed'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      themeColor: json['themeColor']?.toString() ?? '#3b82f6',
      icon: json['icon']?.toString() ?? 'shield',
      star1: (json['star1'] as num?)?.toInt() ?? 0,
      star2: (json['star2'] as num?)?.toInt() ?? 0,
      star3: (json['star3'] as num?)?.toInt() ?? 0,
      star4: (json['star4'] as num?)?.toInt() ?? 0,
      star5: (json['star5'] as num?)?.toInt() ?? 0,
    );
  }

  Color get parsedColor {
    try {
      final hex = themeColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  IconData get iconData {
    switch (key.toLowerCase()) {
      case 'hazard':
        return Icons.shield_rounded;
      case 'inspection':
        return Icons.search_rounded;
      case 'safetytalk':
        return Icons.campaign_rounded;
      case 'observation':
        return Icons.visibility_rounded;
      case 'coaching':
        return Icons.badge_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }
}

class SapQualityItemModel {
  final int id;
  final String programType;
  final String title;
  final String description;
  final DateTime tanggal;
  final String tanggalFormatted;
  final String? lokasi;
  final int rating;
  final String qualityLabel;
  final String qualityColor;
  final String? notes;
  final bool isAuditedBySupervisor;
  final bool isAiAssessed;
  final String? photoUrl;
  final String? hazardPriority;
  final String? hazardBadgeColor;
  final String? hazardDueDateText;

  SapQualityItemModel({
    required this.id,
    required this.programType,
    required this.title,
    required this.description,
    required this.tanggal,
    required this.tanggalFormatted,
    this.lokasi,
    required this.rating,
    required this.qualityLabel,
    required this.qualityColor,
    this.notes,
    required this.isAuditedBySupervisor,
    required this.isAiAssessed,
    this.photoUrl,
    this.hazardPriority,
    this.hazardBadgeColor,
    this.hazardDueDateText,
  });

  factory SapQualityItemModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['tanggal']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return SapQualityItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      programType: json['programType']?.toString() ?? 'SAP',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '-',
      tanggal: parsedDate,
      tanggalFormatted: json['tanggalFormatted']?.toString() ?? '',
      lokasi: json['lokasi']?.toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      qualityLabel: json['qualityLabel']?.toString() ?? '',
      qualityColor: json['qualityColor']?.toString() ?? '#10b981',
      notes: json['notes']?.toString(),
      isAuditedBySupervisor: json['isAuditedBySupervisor'] == true,
      isAiAssessed: json['isAiAssessed'] == true,
      photoUrl: json['photoUrl']?.toString(),
      hazardPriority: json['hazardPriority']?.toString(),
      hazardBadgeColor: json['hazardBadgeColor']?.toString(),
      hazardDueDateText: json['hazardDueDateText']?.toString(),
    );
  }

  Color get parsedQualityColor {
    try {
      final hex = qualityColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  Color get programColor {
    switch (programType.toLowerCase()) {
      case 'hazard':
        return const Color(0xFF6366F1);
      case 'inspection':
        return const Color(0xFF3B82F6);
      case 'safetytalk':
        return const Color(0xFFF59E0B);
      case 'observation':
        return const Color(0xFF14B8A6);
      case 'coaching':
        return const Color(0xFFD946EF);
      default:
        return const Color(0xFF0F766E);
    }
  }

  IconData get programIcon {
    switch (programType.toLowerCase()) {
      case 'hazard':
        return Icons.warning_amber_rounded;
      case 'inspection':
        return Icons.checklist_rounded;
      case 'safetytalk':
        return Icons.campaign_rounded;
      case 'observation':
        return Icons.visibility_rounded;
      case 'coaching':
        return Icons.school_rounded;
      default:
        return Icons.assignment_rounded;
    }
  }
}

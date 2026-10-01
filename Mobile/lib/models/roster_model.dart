class RosterItem {
  final int id;
  final String nik;
  final String awalDinas;
  final String akhirDinas;
  final String awalCuti;
  final String akhirCuti;
  final String awalDinasFormatted;
  final String akhirDinasFormatted;
  final String awalCutiFormatted;
  final String akhirCutiFormatted;
  final String tipeRoster; // "REGULER" or "TUGAS"
  final String? keterangan;
  final String createdAt;
  final int hariDinas;
  final int hariCuti;
  final String status;

  RosterItem({
    required this.id,
    required this.nik,
    required this.awalDinas,
    required this.akhirDinas,
    required this.awalCuti,
    required this.akhirCuti,
    required this.awalDinasFormatted,
    required this.akhirDinasFormatted,
    required this.awalCutiFormatted,
    required this.akhirCutiFormatted,
    required this.tipeRoster,
    this.keterangan,
    required this.createdAt,
    required this.hariDinas,
    required this.hariCuti,
    required this.status,
  });

  bool get isTugas => tipeRoster.toUpperCase() == 'TUGAS';

  factory RosterItem.fromJson(Map<String, dynamic> json) {
    return RosterItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      nik: json['nik']?.toString() ?? '',
      awalDinas: json['awalDinas']?.toString() ?? '',
      akhirDinas: json['akhirDinas']?.toString() ?? '',
      awalCuti: json['awalCuti']?.toString() ?? '',
      akhirCuti: json['akhirCuti']?.toString() ?? '',
      awalDinasFormatted: json['awalDinasFormatted']?.toString() ?? (json['awalDinas']?.toString() ?? ''),
      akhirDinasFormatted: json['akhirDinasFormatted']?.toString() ?? (json['akhirDinas']?.toString() ?? ''),
      awalCutiFormatted: json['awalCutiFormatted']?.toString() ?? (json['awalCuti']?.toString() ?? ''),
      akhirCutiFormatted: json['akhirCutiFormatted']?.toString() ?? (json['akhirCuti']?.toString() ?? ''),
      tipeRoster: json['tipeRoster']?.toString() ?? 'REGULER',
      keterangan: json['keterangan']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      hariDinas: json['hariDinas'] is int ? json['hariDinas'] : int.tryParse('${json['hariDinas']}') ?? 0,
      hariCuti: json['hariCuti'] is int ? json['hariCuti'] : int.tryParse('${json['hariCuti']}') ?? 0,
      status: json['status']?.toString() ?? 'Selesai',
    );
  }
}

class RosterInfoResponse {
  final List<RosterItem> history;
  final Map<String, dynamic>? activeRoster;
  final Map<String, dynamic>? latestRoster;
  final bool isTugasExempt;
  final int computedOnsiteDays;
  final int totalDaysInMonth;
  final double ratio;
  final int defaultOnsite;

  RosterInfoResponse({
    required this.history,
    this.activeRoster,
    this.latestRoster,
    required this.isTugasExempt,
    required this.computedOnsiteDays,
    required this.totalDaysInMonth,
    required this.ratio,
    required this.defaultOnsite,
  });

  factory RosterInfoResponse.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'] as List? ?? [];
    return RosterInfoResponse(
      history: rawHistory.map((item) => RosterItem.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
      activeRoster: json['activeRoster'] != null ? Map<String, dynamic>.from(json['activeRoster'] as Map) : null,
      latestRoster: json['latestRoster'] != null ? Map<String, dynamic>.from(json['latestRoster'] as Map) : null,
      isTugasExempt: json['isTugasExempt'] == true,
      computedOnsiteDays: json['computedOnsiteDays'] is int ? json['computedOnsiteDays'] : int.tryParse('${json['computedOnsiteDays']}') ?? 0,
      totalDaysInMonth: json['totalDaysInMonth'] is int ? json['totalDaysInMonth'] : int.tryParse('${json['totalDaysInMonth']}') ?? 30,
      ratio: (json['ratio'] is num) ? (json['ratio'] as num).toDouble() : 1.0,
      defaultOnsite: json['defaultOnsite'] is int ? json['defaultOnsite'] : int.tryParse('${json['defaultOnsite']}') ?? 42,
    );
  }
}

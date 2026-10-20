class InspectionSummary {
  final int totalSummary;
  final int totalMyInspections;
  final int totalPjaInspections;
  final int totalFindings;
  final int averageScore;

  InspectionSummary({
    this.totalSummary = 0,
    this.totalMyInspections = 0,
    this.totalPjaInspections = 0,
    this.totalFindings = 0,
    this.averageScore = 100,
  });

  factory InspectionSummary.fromJson(Map<String, dynamic> json) {
    return InspectionSummary(
      totalSummary: json['total_summary'] ?? 0,
      totalMyInspections: json['total_my_inspections'] ?? json['total_monitoring'] ?? 0,
      totalPjaInspections: json['total_pja_inspections'] ?? json['total_action'] ?? 0,
      totalFindings: json['total_findings'] ?? 0,
      averageScore: json['average_score'] ?? 100,
    );
  }
}

class InspectionReportItem {
  final int id;
  final String code;
  final String tanggal;
  final String waktu;
  final String nama;
  final String nik;
  final String? departemen;
  final String area;
  final String lokasi;
  final String? detilLokasi;
  final String jenisInspeksi;
  final String? pja;
  final String? nikPja;
  final String? departemenPja;
  final String? catatan;
  final String? image;
  final Map<String, int> scores;
  final List<Map<String, dynamic>> customQuestions;
  final bool isOfflinePending;
  final bool isMyReport;
  final bool isAssignedToMe;
  final String? createdAt;

  InspectionReportItem({
    required this.id,
    required this.code,
    required this.tanggal,
    required this.waktu,
    required this.nama,
    required this.nik,
    this.departemen,
    required this.area,
    required this.lokasi,
    this.detilLokasi,
    required this.jenisInspeksi,
    this.pja,
    this.nikPja,
    this.departemenPja,
    this.catatan,
    this.image,
    required this.scores,
    this.customQuestions = const [],
    this.isOfflinePending = false,
    this.isMyReport = false,
    this.isAssignedToMe = false,
    this.createdAt,
  });

  int get totalCheckpoints => scores.length + customQuestions.length;

  int get totalFindings {
    int count = 0;
    scores.forEach((_, v) {
      if (v == 0) count++;
    });
    for (var q in customQuestions) {
      if (q['score'] == 0) count++;
    }
    return count;
  }

  int get totalCompliant {
    int count = 0;
    scores.forEach((_, v) {
      if (v == 2) count++;
    });
    for (var q in customQuestions) {
      if (q['score'] == 2) count++;
    }
    return count;
  }

  int get compliancePercent {
    final relevant = totalCompliant + totalFindings;
    if (relevant == 0) return 100;
    return ((totalCompliant / relevant) * 100).round();
  }
}

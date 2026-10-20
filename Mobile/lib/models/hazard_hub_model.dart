class HazardSummary {
  final int totalInput;
  final int totalSummary;
  final int totalOpen;
  final int totalClosed;
  final int totalAssigned;
  final int totalAction;
  final int totalMonitoring;
  final int totalSite;
  final int score;

  HazardSummary({
    this.totalInput = 0,
    this.totalSummary = 0,
    this.totalOpen = 0,
    this.totalClosed = 0,
    this.totalAssigned = 0,
    this.totalAction = 0,
    this.totalMonitoring = 0,
    this.totalSite = 0,
    this.score = 0,
  });

  factory HazardSummary.fromJson(Map<String, dynamic> json) {
    final action = json['total_action'] ?? json['total_assigned'] ?? 0;
    final monitoring = json['total_monitoring'] ?? json['total_open'] ?? 0;
    final summary = json['total_summary'] ?? json['total_closed'] ?? 0;
    final site = json['total_site'] ?? 0;

    return HazardSummary(
      totalInput: json['total_input'] ?? 0,
      totalSummary: summary,
      totalOpen: monitoring,
      totalClosed: summary,
      totalAssigned: action,
      totalAction: action,
      totalMonitoring: monitoring,
      totalSite: site,
      score: json['score'] ?? 0,
    );
  }
}

class HazardReportItem {
  final int id;
  final String tanggal;
  final String waktu;
  final String nama;
  final String nik;
  final String? departemen;
  final String? area;
  final String? lokasi;
  final String? detilLokasi;
  final String temuan;
  final String? kategoriBahaya;
  final String? jenisBahaya;
  final String? jenisKetidaksesuaian;
  final String tingkatResiko;
  final String? perbaikan;
  final String? tindakanPerbaikan;
  final String? pja;
  final String? nikPja;
  final String? departemenPja;
  final String statusTemuan;
  final String? fotoTemuan;
  final String? fotoPerbaikan;
  final String? createdAt;
  final bool isMyReport;
  final bool isAssignedToMe;
  final bool canTakeUp;
  final bool canClose;
  final bool canReassign;
  final bool canDelete;
  final bool isOfflinePending;

  HazardReportItem({
    required this.id,
    required this.tanggal,
    required this.waktu,
    required this.nama,
    required this.nik,
    this.departemen,
    this.area,
    this.lokasi,
    this.detilLokasi,
    required this.temuan,
    this.kategoriBahaya,
    this.jenisBahaya,
    this.jenisKetidaksesuaian,
    this.tingkatResiko = 'Rendah',
    this.perbaikan,
    this.tindakanPerbaikan,
    this.pja,
    this.nikPja,
    this.departemenPja,
    this.statusTemuan = 'Open',
    this.fotoTemuan,
    this.fotoPerbaikan,
    this.createdAt,
    this.isMyReport = false,
    this.isAssignedToMe = false,
    this.canTakeUp = false,
    this.canClose = false,
    this.canReassign = false,
    this.canDelete = false,
    this.isOfflinePending = false,
  });

  factory HazardReportItem.fromJson(Map<String, dynamic> json) {
    return HazardReportItem(
      id: json['id'] ?? 0,
      tanggal: json['tanggal']?.toString() ?? '',
      waktu: json['waktu']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      nik: json['nik']?.toString() ?? '',
      departemen: json['departemen']?.toString(),
      area: json['area']?.toString(),
      lokasi: json['lokasi']?.toString(),
      detilLokasi: json['detil_lokasi']?.toString(),
      temuan: json['temuan']?.toString() ?? '',
      kategoriBahaya: json['kategori_bahaya']?.toString(),
      jenisBahaya: json['jenis_bahaya']?.toString(),
      jenisKetidaksesuaian: json['jenis_ketidaksesuaian']?.toString(),
      tingkatResiko: json['tingkat_resiko']?.toString() ?? 'Rendah',
      perbaikan: json['perbaikan']?.toString(),
      tindakanPerbaikan: json['tindakan_perbaikan']?.toString(),
      pja: json['pja']?.toString(),
      nikPja: json['nik_pja']?.toString(),
      departemenPja: json['departemen_pja']?.toString(),
      statusTemuan: json['status_temuan']?.toString() ?? 'Open',
      fotoTemuan: json['foto_temuan']?.toString(),
      fotoPerbaikan: json['foto_perbaikan']?.toString(),
      createdAt: json['created_at']?.toString(),
      isMyReport: json['is_my_report'] == true,
      isAssignedToMe: json['is_assigned_to_me'] == true,
      canTakeUp: json['can_take_up'] == true ||
          (json['is_assigned_to_me'] == true &&
              (json['status_temuan']?.toString().toLowerCase() == 'open')),
      canClose: json['can_close'] == true,
      canReassign: json['can_reassign'] == true,
      canDelete: json['can_delete'] == true,
      isOfflinePending: json['is_offline_pending'] == true,
    );
  }
}

class PjaSearchResult {
  final String nik;
  final String nama;
  final String jabatan;
  final String departemen;
  final String perusahaan;

  PjaSearchResult({
    required this.nik,
    required this.nama,
    required this.jabatan,
    required this.departemen,
    required this.perusahaan,
  });

  factory PjaSearchResult.fromJson(Map<String, dynamic> json) {
    return PjaSearchResult(
      nik: json['nik']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      jabatan: json['jabatan']?.toString() ?? '',
      departemen: json['departemen']?.toString() ?? '',
      perusahaan: json['perusahaan']?.toString() ?? '',
    );
  }
}

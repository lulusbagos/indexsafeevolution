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
    final tgl = json['tanggal']?.toString() ?? json['date']?.toString() ?? '';
    final wkt = json['waktu']?.toString() ?? json['time']?.toString() ?? '';
    final empNama = json['nama']?.toString() ?? json['employee_name']?.toString() ?? '';
    final empNik = json['nik']?.toString() ?? json['employee_nik']?.toString() ?? '';
    final tmn = json['temuan']?.toString() ?? json['remark']?.toString() ?? json['detil_temuan']?.toString() ?? json['title']?.toString() ?? '';
    final ar = json['area']?.toString() ?? json['area_name']?.toString();
    final lok = json['lokasi']?.toString() ?? json['location_name']?.toString();
    final detLok = json['detil_lokasi']?.toString() ?? json['location_detail']?.toString();
    final pj = json['pja']?.toString() ?? json['pja_name']?.toString();
    final imgTemuan = json['foto_temuan']?.toString() ?? json['image']?.toString();
    final imgRepair = json['foto_perbaikan']?.toString() ?? json['image_repair']?.toString() ?? json['repair_image']?.toString();

    String stat = json['status_temuan']?.toString() ?? '';
    if (stat.isEmpty) {
      if (json['status'] == 1 || json['status'] == '1' || json['status'] == 'closed' || json['status'] == 'Closed') {
        stat = 'Closed';
      } else if (json['status'] == 2 || json['status'] == '2') {
        stat = 'In Progress';
      } else {
        stat = 'Open';
      }
    }

    final isOffline = json['is_offline_pending'] == true || (json.containsKey('sync_id') && json['sync_id'] == null);

    return HazardReportItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      tanggal: tgl,
      waktu: wkt,
      nama: empNama,
      nik: empNik,
      departemen: json['departemen']?.toString() ?? json['dept_name']?.toString(),
      area: ar,
      lokasi: lok,
      detilLokasi: detLok,
      temuan: tmn,
      kategoriBahaya: json['kategori_bahaya']?.toString(),
      jenisBahaya: json['jenis_bahaya']?.toString(),
      jenisKetidaksesuaian: json['jenis_ketidaksesuaian']?.toString(),
      tingkatResiko: json['tingkat_resiko']?.toString() ?? json['resiko']?.toString() ?? 'Rendah',
      perbaikan: json['perbaikan']?.toString() ?? json['action_taken']?.toString(),
      tindakanPerbaikan: json['tindakan_perbaikan']?.toString(),
      pja: pj,
      nikPja: json['nik_pja']?.toString(),
      departemenPja: json['departemen_pja']?.toString(),
      statusTemuan: stat,
      fotoTemuan: imgTemuan,
      fotoPerbaikan: imgRepair,
      createdAt: json['created_at']?.toString(),
      isMyReport: json['is_my_report'] == true,
      isAssignedToMe: json['is_assigned_to_me'] == true,
      canTakeUp: json['can_take_up'] == true ||
          (json['is_assigned_to_me'] == true && stat.toLowerCase() == 'open'),
      canClose: json['can_close'] == true,
      canReassign: json['can_reassign'] == true,
      canDelete: json['can_delete'] == true || isOffline,
      isOfflinePending: isOffline,
    );
  }
}

class PjaSearchResult {
  final String nik;
  final String nama;
  final String jabatan;
  final String departemen;
  final String perusahaan;
  final String? foto;
  final bool isAssignedArea;
  final bool isPicUtama;

  PjaSearchResult({
    required this.nik,
    required this.nama,
    required this.jabatan,
    required this.departemen,
    required this.perusahaan,
    this.foto,
    this.isAssignedArea = false,
    this.isPicUtama = false,
  });

  factory PjaSearchResult.fromJson(Map<String, dynamic> json) {
    return PjaSearchResult(
      nik: json['nik']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      jabatan: json['jabatan']?.toString() ?? '',
      departemen: json['departemen']?.toString() ?? '',
      perusahaan: json['perusahaan']?.toString() ?? '',
      foto: (json['foto'] ?? json['pathFoto'] ?? json['path_foto'])?.toString(),
      isAssignedArea: json['is_assigned_area'] == true,
      isPicUtama: json['is_pic_utama'] == true,
    );
  }
}

class RciMemberItem {
  final int id;
  final int? rciReportId;
  final String role; // 'Creator' or 'Approver'
  final String nik;
  final String nama;
  final String? jabatan;
  final String? perusahaan;
  final int? perusahaanId;
  final String status; // 'Pending', 'Approved', 'Confirmed'
  final DateTime? actionAt;
  final DateTime? createdAt;

  RciMemberItem({
    required this.id,
    this.rciReportId,
    required this.role,
    required this.nik,
    required this.nama,
    this.jabatan,
    this.perusahaan,
    this.perusahaanId,
    this.status = 'Pending',
    this.actionAt,
    this.createdAt,
  });

  factory RciMemberItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return RciMemberItem(
      id: json['id'] ?? json['Id'] ?? 0,
      rciReportId: json['rciReportId'] ?? json['RciReportId'],
      role: (json['role'] ?? json['Role'] ?? 'Creator').toString(),
      nik: (json['nik'] ?? json['Nik'] ?? '').toString(),
      nama: (json['nama'] ?? json['Nama'] ?? '').toString(),
      jabatan: json['jabatan'] ?? json['Jabatan'],
      perusahaan: json['perusahaan'] ?? json['Perusahaan'],
      perusahaanId: json['perusahaanId'] ?? json['PerusahaanId'],
      status: (json['status'] ?? json['Status'] ?? 'Pending').toString(),
      actionAt: parseDate(json['actionAt'] ?? json['ActionAt']),
      createdAt: parseDate(json['createdAt'] ?? json['CreatedAt']),
    );
  }
}

class RciReportItem {
  final int id;
  final DateTime tanggal;
  final String waktu;
  final String nik;
  final String nama;
  final String? departemen;
  final String? perusahaan;
  final int? perusahaanId;
  final String area;
  final String lokasi;
  final String? detilLokasi;
  final String? namaJalan;
  final String? segmentJalan;
  final String? shift;
  final String? latitude;
  final String? longitude;
  final double? panjangSegment;

  // Deficits (meter)
  final double defisitSurfacing;
  final double defisitUndulation;
  final double defisitSpoil;
  final double defisitSafetyBerm;
  final double defisitRoadAttachment;
  final double defisitDust;
  final double defisitCrossfall;
  final double defisitDrainage;

  // 8 Scores (scale 2.0 - 4.0)
  final double skorSurfacing;
  final double skorUndulation;
  final double skorSpoil;
  final double skorSafetyBerm;
  final double skorRoadAttachment;
  final double skorDust;
  final double skorCrossfall;
  final double skorDrainage;

  // 3 Pillar Group Scores
  final double skorPermukaanGroup;
  final double skorSafetyBermGroup;
  final double skorDrainageGroup;

  // Total Scores & Achievement
  final double actualRoadScore;
  final double targetScore;
  final double achievement;
  final double totalScore;
  final String kategoriIndex;

  final String? catatan;
  final String? tindakanPerbaikan;
  final String? pic;
  final String? fotoUrl;

  final String status; // 'Pending', 'Approved'
  final DateTime? approvedAt;
  final String? creatorsSummary;
  final String? approversSummary;
  final List<RciMemberItem> members;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RciReportItem({
    required this.id,
    required this.tanggal,
    required this.waktu,
    required this.nik,
    required this.nama,
    this.departemen,
    this.perusahaan,
    this.perusahaanId,
    required this.area,
    required this.lokasi,
    this.detilLokasi,
    this.namaJalan,
    this.segmentJalan,
    this.shift,
    this.latitude,
    this.longitude,
    this.panjangSegment = 100.0,
    this.defisitSurfacing = 0.0,
    this.defisitUndulation = 0.0,
    this.defisitSpoil = 0.0,
    this.defisitSafetyBerm = 0.0,
    this.defisitRoadAttachment = 0.0,
    this.defisitDust = 0.0,
    this.defisitCrossfall = 0.0,
    this.defisitDrainage = 0.0,
    this.skorSurfacing = 4.0,
    this.skorUndulation = 4.0,
    this.skorSpoil = 4.0,
    this.skorSafetyBerm = 4.0,
    this.skorRoadAttachment = 4.0,
    this.skorDust = 4.0,
    this.skorCrossfall = 4.0,
    this.skorDrainage = 4.0,
    this.skorPermukaanGroup = 4.0,
    this.skorSafetyBermGroup = 4.0,
    this.skorDrainageGroup = 4.0,
    this.actualRoadScore = 4.0,
    this.targetScore = 4.0,
    this.achievement = 100.0,
    this.totalScore = 4.0,
    this.kategoriIndex = 'Baik',
    this.catatan,
    this.tindakanPerbaikan,
    this.pic,
    this.fotoUrl,
    this.status = 'Pending',
    this.approvedAt,
    this.creatorsSummary,
    this.approversSummary,
    this.members = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory RciReportItem.fromJson(Map<String, dynamic> json) {
    DateTime tgl = DateTime.now();
    if (json['tanggal'] != null) {
      tgl = DateTime.tryParse(json['tanggal'].toString()) ?? DateTime.now();
    } else if (json['Tanggal'] != null) {
      tgl = DateTime.tryParse(json['Tanggal'].toString()) ?? DateTime.now();
    }

    String waktuStr = '00:00';
    if (json['waktu'] != null) {
      waktuStr = json['waktu'].toString();
    } else if (json['Waktu'] != null) {
      waktuStr = json['Waktu'].toString();
    }
    if (waktuStr.length > 5) {
      waktuStr = waktuStr.substring(0, 5);
    }

    double parseDbl(dynamic val, [double def = 0.0]) {
      if (val == null) return def;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      return double.tryParse(val.toString()) ?? def;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    List<RciMemberItem> parseMembers(dynamic val) {
      if (val is List) {
        return val.map((e) {
          if (e is Map) return RciMemberItem.fromJson(Map<String, dynamic>.from(e));
          return null;
        }).whereType<RciMemberItem>().toList();
      }
      return [];
    }

    double actual = parseDbl(json['actualRoadScore'] ?? json['ActualRoadScore'], 0.0);
    double tot = parseDbl(json['totalScore'] ?? json['TotalScore'], 0.0);
    if (actual <= 0.0) {
      actual = tot > 4.0 ? (tot / 25.0) : (tot > 0 ? tot : 4.0);
    }

    double ach = parseDbl(json['achievement'] ?? json['Achievement'], 0.0);
    if (ach <= 0.0) {
      ach = (actual / 4.0) * 100.0;
    }

    return RciReportItem(
      id: json['id'] ?? json['Id'] ?? 0,
      tanggal: tgl,
      waktu: waktuStr,
      nik: (json['nik'] ?? json['Nik'] ?? '').toString(),
      nama: (json['nama'] ?? json['Nama'] ?? '').toString(),
      departemen: json['departemen'] ?? json['Departemen'],
      perusahaan: json['perusahaan'] ?? json['Perusahaan'],
      perusahaanId: json['perusahaanId'] ?? json['PerusahaanId'],
      area: (json['area'] ?? json['Area'] ?? '').toString(),
      lokasi: (json['lokasi'] ?? json['Lokasi'] ?? '').toString(),
      detilLokasi: json['detilLokasi'] ?? json['DetilLokasi'],
      namaJalan: json['namaJalan'] ?? json['NamaJalan'],
      segmentJalan: json['segmentJalan'] ?? json['SegmentJalan'],
      shift: json['shift'] ?? json['Shift'],
      latitude: json['latitude'] ?? json['Latitude'],
      longitude: json['longitude'] ?? json['Longitude'],
      panjangSegment: parseDbl(json['panjangSegment'] ?? json['PanjangSegment'], 100.0),
      defisitSurfacing: parseDbl(json['defisitSurfacing'] ?? json['DefisitSurfacing'], 0.0),
      defisitUndulation: parseDbl(json['defisitUndulation'] ?? json['DefisitUndulation'], 0.0),
      defisitSpoil: parseDbl(json['defisitSpoil'] ?? json['DefisitSpoil'], 0.0),
      defisitSafetyBerm: parseDbl(json['defisitSafetyBerm'] ?? json['DefisitSafetyBerm'], 0.0),
      defisitRoadAttachment: parseDbl(json['defisitRoadAttachment'] ?? json['DefisitRoadAttachment'], 0.0),
      defisitDust: parseDbl(json['defisitDust'] ?? json['DefisitDust'], 0.0),
      defisitCrossfall: parseDbl(json['defisitCrossfall'] ?? json['DefisitCrossfall'], 0.0),
      defisitDrainage: parseDbl(json['defisitDrainage'] ?? json['DefisitDrainage'], 0.0),
      skorSurfacing: parseDbl(json['skorSurfacing'] ?? json['SkorSurfacing'], 4.0),
      skorUndulation: parseDbl(json['skorUndulation'] ?? json['SkorUndulation'], 4.0),
      skorSpoil: parseDbl(json['skorSpoil'] ?? json['SkorSpoil'], 4.0),
      skorSafetyBerm: parseDbl(json['skorSafetyBerm'] ?? json['SkorSafetyBerm'], 4.0),
      skorRoadAttachment: parseDbl(json['skorRoadAttachment'] ?? json['SkorRoadAttachment'], 4.0),
      skorDust: parseDbl(json['skorDust'] ?? json['SkorDust'], 4.0),
      skorCrossfall: parseDbl(json['skorCrossfall'] ?? json['SkorCrossfall'], 4.0),
      skorDrainage: parseDbl(json['skorDrainage'] ?? json['SkorDrainage'], 4.0),
      skorPermukaanGroup: parseDbl(json['skorPermukaanGroup'] ?? json['SkorPermukaanGroup'], 4.0),
      skorSafetyBermGroup: parseDbl(json['skorSafetyBermGroup'] ?? json['SkorSafetyBermGroup'], 4.0),
      skorDrainageGroup: parseDbl(json['skorDrainageGroup'] ?? json['SkorDrainageGroup'], 4.0),
      actualRoadScore: actual,
      targetScore: parseDbl(json['targetScore'] ?? json['TargetScore'], 4.0),
      achievement: ach,
      totalScore: tot > 0 ? tot : (actual * 25.0),
      kategoriIndex: (json['kategoriIndex'] ?? json['KategoriIndex'] ?? 'Baik').toString(),
      catatan: json['catatan'] ?? json['Catatan'],
      tindakanPerbaikan: json['tindakanPerbaikan'] ?? json['TindakanPerbaikan'],
      pic: json['pic'] ?? json['Pic'],
      fotoUrl: json['fotoUrl'] ?? json['FotoUrl'],
      status: (json['status'] ?? json['Status'] ?? 'Pending').toString(),
      approvedAt: parseDate(json['approvedAt'] ?? json['ApprovedAt']),
      creatorsSummary: json['creatorsSummary'] ?? json['CreatorsSummary'],
      approversSummary: json['approversSummary'] ?? json['ApproversSummary'],
      members: parseMembers(json['members'] ?? json['Members']),
      createdAt: parseDate(json['createdAt'] ?? json['CreatedAt']),
      updatedAt: parseDate(json['updatedAt'] ?? json['UpdatedAt']),
    );
  }
}

class RciSummaryStats {
  final int totalReports;
  final double avgScore;
  final double avgAchievement;
  final int goodCount;
  final int fairCount;
  final int poorCount;
  final int pendingCount;
  final int approvedCount;
  final int myPendingApprovalsCount;
  final int myJointCount;

  RciSummaryStats({
    this.totalReports = 0,
    this.avgScore = 4.0,
    this.avgAchievement = 100.0,
    this.goodCount = 0,
    this.fairCount = 0,
    this.poorCount = 0,
    this.pendingCount = 0,
    this.approvedCount = 0,
    this.myPendingApprovalsCount = 0,
    this.myJointCount = 0,
  });

  factory RciSummaryStats.fromJson(Map<String, dynamic> json) {
    double parseDbl(dynamic v, [double def = 0.0]) {
      if (v == null) return def;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? def;
    }

    int parseInt(dynamic v, [int def = 0]) {
      if (v == null) return def;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? def;
    }

    return RciSummaryStats(
      totalReports: parseInt(json['totalReports']),
      avgScore: parseDbl(json['avgScore'], 4.0),
      avgAchievement: parseDbl(json['avgAchievement'], 100.0),
      goodCount: parseInt(json['goodCount']),
      fairCount: parseInt(json['fairCount']),
      poorCount: parseInt(json['poorCount']),
      pendingCount: parseInt(json['pendingCount']),
      approvedCount: parseInt(json['approvedCount']),
      myPendingApprovalsCount: parseInt(json['myPendingApprovalsCount']),
      myJointCount: parseInt(json['myJointCount']),
    );
  }
}

class DciReportItem {
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
  final String? disposal;
  final String? namaDump;
  final String? pad;
  final String? shift;
  final String? latitude;
  final String? longitude;
  final int skorLantaiDump;
  final int skorSafetyBerm;
  final int skorKondisiCrest;
  final int skorGradeDumping;
  final int skorDrainaseDump;
  final int skorPenataanSpillage;
  final int skorRambuPenerangan;
  final int skorSpotterManuver;
  final double totalScore;
  final String kategoriIndex;
  final String? catatan;
  final String? tindakanPerbaikan;
  final String? pic;
  final String? fotoUrl;
  final DateTime? createdAt;

  DciReportItem({
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
    this.disposal,
    this.namaDump,
    this.pad,
    this.shift,
    this.latitude,
    this.longitude,
    this.skorLantaiDump = 100,
    this.skorSafetyBerm = 100,
    this.skorKondisiCrest = 100,
    this.skorGradeDumping = 100,
    this.skorDrainaseDump = 100,
    this.skorPenataanSpillage = 100,
    this.skorRambuPenerangan = 100,
    this.skorSpotterManuver = 100,
    this.totalScore = 100.0,
    this.kategoriIndex = 'Baik',
    this.catatan,
    this.tindakanPerbaikan,
    this.pic,
    this.fotoUrl,
    this.createdAt,
  });

  factory DciReportItem.fromJson(Map<String, dynamic> json) {
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

    int parseScore(dynamic val) {
      if (val == null) return 100;
      if (val is int) return val;
      if (val is double) return val.toInt();
      return int.tryParse(val.toString()) ?? 100;
    }

    double parseTotal(dynamic val) {
      if (val == null) return 100.0;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      return double.tryParse(val.toString()) ?? 100.0;
    }

    return DciReportItem(
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
      disposal: json['disposal'] ?? json['Disposal'],
      namaDump: json['namaDump'] ?? json['NamaDump'],
      pad: json['pad'] ?? json['Pad'] ?? json['nama_pad'] ?? json['namaPad'],
      shift: json['shift'] ?? json['Shift'],
      latitude: json['latitude'] ?? json['Latitude'],
      longitude: json['longitude'] ?? json['Longitude'],
      skorLantaiDump: parseScore(json['skorLantaiDump'] ?? json['SkorLantaiDump']),
      skorSafetyBerm: parseScore(json['skorSafetyBerm'] ?? json['SkorSafetyBerm']),
      skorKondisiCrest: parseScore(json['skorKondisiCrest'] ?? json['SkorKondisiCrest']),
      skorGradeDumping: parseScore(json['skorGradeDumping'] ?? json['SkorGradeDumping']),
      skorDrainaseDump: parseScore(json['skorDrainaseDump'] ?? json['SkorDrainaseDump']),
      skorPenataanSpillage: parseScore(json['skorPenataanSpillage'] ?? json['SkorPenataanSpillage']),
      skorRambuPenerangan: parseScore(json['skorRambuPenerangan'] ?? json['SkorRambuPenerangan']),
      skorSpotterManuver: parseScore(json['skorSpotterManuver'] ?? json['SkorSpotterManuver']),
      totalScore: parseTotal(json['totalScore'] ?? json['TotalScore']),
      kategoriIndex: (json['kategoriIndex'] ?? json['KategoriIndex'] ?? 'Baik').toString(),
      catatan: json['catatan'] ?? json['Catatan'],
      tindakanPerbaikan: json['tindakanPerbaikan'] ?? json['TindakanPerbaikan'],
      pic: json['pic'] ?? json['Pic'],
      fotoUrl: json['fotoUrl'] ?? json['FotoUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : (json['CreatedAt'] != null ? DateTime.tryParse(json['CreatedAt'].toString()) : null),
    );
  }
}

class DciSummaryStats {
  final int totalReports;
  final double avgScore;
  final int goodCount;
  final int fairCount;
  final int poorCount;

  DciSummaryStats({
    this.totalReports = 0,
    this.avgScore = 100.0,
    this.goodCount = 0,
    this.fairCount = 0,
    this.poorCount = 0,
  });

  factory DciSummaryStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DciSummaryStats();
    return DciSummaryStats(
      totalReports: json['totalReports'] ?? 0,
      avgScore: (json['avgScore'] != null)
          ? double.tryParse(json['avgScore'].toString()) ?? 100.0
          : 100.0,
      goodCount: json['goodCount'] ?? 0,
      fairCount: json['fairCount'] ?? 0,
      poorCount: json['poorCount'] ?? 0,
    );
  }
}

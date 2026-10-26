class GciReportItem {
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
  final String? pit;
  final String? namaLereng;
  final String? areaType;
  final String? shift;
  final String? latitude;
  final String? longitude;
  final int skorGeometriLereng;
  final int skorKondisiCrestToe;
  final int skorTensionCrack;
  final int skorKestabilanBatuan;
  final int skorRembesanDrainase;
  final int skorPemantauanSensor;
  final int skorDemarkasiZona;
  final int skorKepatuhanRekomendasi;
  final double totalScore;
  final String kategoriIndex;
  final String tarpLevel;
  final String? catatan;
  final String? tindakanPerbaikan;
  final String? pic;
  final String? picNik;
  final String? judulTemuan;
  final DateTime? dueDate;
  final String? fotoUrl;
  final String? jenisInspeksi;
  final String? pjaNama;
  final String? pjaNik;
  final DateTime? createdAt;

  GciReportItem({
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
    this.pit,
    this.namaLereng,
    this.areaType = 'Highwall',
    this.shift,
    this.latitude,
    this.longitude,
    this.skorGeometriLereng = 100,
    this.skorKondisiCrestToe = 100,
    this.skorTensionCrack = 100,
    this.skorKestabilanBatuan = 100,
    this.skorRembesanDrainase = 100,
    this.skorPemantauanSensor = 100,
    this.skorDemarkasiZona = 100,
    this.skorKepatuhanRekomendasi = 100,
    this.totalScore = 100.0,
    this.kategoriIndex = 'Baik',
    this.tarpLevel = 'GREEN',
    this.catatan,
    this.tindakanPerbaikan,
    this.pic,
    this.picNik,
    this.judulTemuan,
    this.dueDate,
    this.fotoUrl,
    this.jenisInspeksi = 'Inspeksi Rutin',
    this.pjaNama,
    this.pjaNik,
    this.createdAt,
  });

  factory GciReportItem.fromJson(Map<String, dynamic> json) {
    DateTime tgl = DateTime.now();
    if (json['tanggal'] != null) {
      tgl = DateTime.tryParse(json['tanggal'].toString()) ?? DateTime.now();
    } else if (json['Tanggal'] != null) {
      tgl = DateTime.tryParse(json['Tanggal'].toString()) ?? DateTime.now();
    }

    DateTime? due;
    if (json['dueDate'] != null) {
      due = DateTime.tryParse(json['dueDate'].toString());
    } else if (json['DueDate'] != null) {
      due = DateTime.tryParse(json['DueDate'].toString());
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

    return GciReportItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      tanggal: tgl,
      waktu: waktuStr,
      nik: json['nik']?.toString() ?? json['Nik']?.toString() ?? '',
      nama: json['nama']?.toString() ?? json['Nama']?.toString() ?? '',
      departemen: json['departemen']?.toString() ?? json['Departemen']?.toString(),
      perusahaan: json['perusahaan']?.toString() ?? json['Perusahaan']?.toString(),
      perusahaanId: json['perusahaanId'] is int
          ? json['perusahaanId']
          : (json['PerusahaanId'] is int
              ? json['PerusahaanId']
              : int.tryParse(json['perusahaanId']?.toString() ?? json['PerusahaanId']?.toString() ?? '')),
      area: json['area']?.toString() ?? json['Area']?.toString() ?? '',
      lokasi: json['lokasi']?.toString() ?? json['Lokasi']?.toString() ?? '',
      detilLokasi: json['detilLokasi']?.toString() ?? json['DetilLokasi']?.toString(),
      pit: json['pit']?.toString() ?? json['Pit']?.toString(),
      namaLereng: json['namaLereng']?.toString() ?? json['NamaLereng']?.toString(),
      areaType: json['areaType']?.toString() ?? json['AreaType']?.toString() ?? 'Highwall',
      shift: json['shift']?.toString() ?? json['Shift']?.toString(),
      latitude: json['latitude']?.toString() ?? json['Latitude']?.toString(),
      longitude: json['longitude']?.toString() ?? json['Longitude']?.toString(),
      skorGeometriLereng: parseScore(json['skorGeometriLereng'] ?? json['SkorGeometriLereng']),
      skorKondisiCrestToe: parseScore(json['skorKondisiCrestToe'] ?? json['SkorKondisiCrestToe']),
      skorTensionCrack: parseScore(json['skorTensionCrack'] ?? json['SkorTensionCrack']),
      skorKestabilanBatuan: parseScore(json['skorKestabilanBatuan'] ?? json['SkorKestabilanBatuan']),
      skorRembesanDrainase: parseScore(json['skorRembesanDrainase'] ?? json['SkorRembesanDrainase']),
      skorPemantauanSensor: parseScore(json['skorPemantauanSensor'] ?? json['SkorPemantauanSensor']),
      skorDemarkasiZona: parseScore(json['skorDemarkasiZona'] ?? json['SkorDemarkasiZona']),
      skorKepatuhanRekomendasi: parseScore(json['skorKepatuhanRekomendasi'] ?? json['SkorKepatuhanRekomendasi']),
      totalScore: parseTotal(json['totalScore'] ?? json['TotalScore']),
      kategoriIndex: json['kategoriIndex']?.toString() ?? json['KategoriIndex']?.toString() ?? 'Baik',
      tarpLevel: json['tarpLevel']?.toString() ?? json['TarpLevel']?.toString() ?? 'GREEN',
      catatan: json['catatan']?.toString() ?? json['Catatan']?.toString(),
      tindakanPerbaikan: json['tindakanPerbaikan']?.toString() ?? json['TindakanPerbaikan']?.toString(),
      pic: json['pic']?.toString() ?? json['Pic']?.toString(),
      picNik: json['picNik']?.toString() ?? json['PicNik']?.toString(),
      judulTemuan: json['judulTemuan']?.toString() ?? json['JudulTemuan']?.toString(),
      dueDate: due,
      fotoUrl: json['fotoUrl']?.toString() ?? json['FotoUrl']?.toString(),
      jenisInspeksi: json['jenisInspeksi']?.toString() ?? json['JenisInspeksi']?.toString() ?? 'Inspeksi Rutin',
      pjaNama: json['pjaNama']?.toString() ?? json['PjaNama']?.toString(),
      pjaNik: json['pjaNik']?.toString() ?? json['PjaNik']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tanggal': tanggal.toIso8601String(),
    'waktu': waktu,
    'nik': nik,
    'nama': nama,
    'departemen': departemen,
    'perusahaan': perusahaan,
    'perusahaanId': perusahaanId,
    'area': area,
    'lokasi': lokasi,
    'detilLokasi': detilLokasi,
    'pit': pit,
    'namaLereng': namaLereng,
    'areaType': areaType,
    'shift': shift,
    'latitude': latitude,
    'longitude': longitude,
    'skorGeometriLereng': skorGeometriLereng,
    'skorKondisiCrestToe': skorKondisiCrestToe,
    'skorTensionCrack': skorTensionCrack,
    'skorKestabilanBatuan': skorKestabilanBatuan,
    'skorRembesanDrainase': skorRembesanDrainase,
    'skorPemantauanSensor': skorPemantauanSensor,
    'skorDemarkasiZona': skorDemarkasiZona,
    'skorKepatuhanRekomendasi': skorKepatuhanRekomendasi,
    'totalScore': totalScore,
    'kategoriIndex': kategoriIndex,
    'tarpLevel': tarpLevel,
    'catatan': catatan,
    'tindakanPerbaikan': tindakanPerbaikan,
    'pic': pic,
    'picNik': picNik,
    'judulTemuan': judulTemuan,
    'dueDate': dueDate?.toIso8601String(),
    'fotoUrl': fotoUrl,
    'jenisInspeksi': jenisInspeksi,
    'pjaNama': pjaNama,
    'pjaNik': pjaNik,
    'createdAt': createdAt?.toIso8601String(),
  };
}

class GciSummaryStats {
  final int totalReports;
  final double avgScore;
  final int goodCount;
  final int fairCount;
  final int poorCount;
  final int tarpGreenCount;
  final int tarpYellowCount;
  final int tarpOrangeCount;
  final int tarpRedCount;

  GciSummaryStats({
    this.totalReports = 0,
    this.avgScore = 100.0,
    this.goodCount = 0,
    this.fairCount = 0,
    this.poorCount = 0,
    this.tarpGreenCount = 0,
    this.tarpYellowCount = 0,
    this.tarpOrangeCount = 0,
    this.tarpRedCount = 0,
  });

  factory GciSummaryStats.fromJson(Map<String, dynamic> json) {
    return GciSummaryStats(
      totalReports: json['totalReports'] is int ? json['totalReports'] : int.tryParse(json['totalReports']?.toString() ?? '0') ?? 0,
      avgScore: (json['avgScore'] is num) ? (json['avgScore'] as num).toDouble() : double.tryParse(json['avgScore']?.toString() ?? '100.0') ?? 100.0,
      goodCount: json['goodCount'] is int ? json['goodCount'] : int.tryParse(json['goodCount']?.toString() ?? '0') ?? 0,
      fairCount: json['fairCount'] is int ? json['fairCount'] : int.tryParse(json['fairCount']?.toString() ?? '0') ?? 0,
      poorCount: json['poorCount'] is int ? json['poorCount'] : int.tryParse(json['poorCount']?.toString() ?? '0') ?? 0,
      tarpGreenCount: json['tarpGreenCount'] is int ? json['tarpGreenCount'] : int.tryParse(json['tarpGreenCount']?.toString() ?? '0') ?? 0,
      tarpYellowCount: json['tarpYellowCount'] is int ? json['tarpYellowCount'] : int.tryParse(json['tarpYellowCount']?.toString() ?? '0') ?? 0,
      tarpOrangeCount: json['tarpOrangeCount'] is int ? json['tarpOrangeCount'] : int.tryParse(json['tarpOrangeCount']?.toString() ?? '0') ?? 0,
      tarpRedCount: json['tarpRedCount'] is int ? json['tarpRedCount'] : int.tryParse(json['tarpRedCount']?.toString() ?? '0') ?? 0,
    );
  }
}

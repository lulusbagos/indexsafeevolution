class SpiReportItem {
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
  final String? namaKolam;
  final String? titikPenaatan;
  final String? shift;
  final String? latitude;
  final String? longitude;
  final int skorKapasitasEndapan;
  final int skorKondisiTanggul;
  final int skorSekatBaffle;
  final int skorPelimpahSpillway;
  final int skorFasilitasDosing;
  final int skorKualitasAirFisik;
  final int skorTitikPenaatanDebit;
  final int skorRambuPengaman;
  final double totalScore;
  final String kategoriIndex;
  final String? catatan;
  final String? tindakanPerbaikan;
  final String? pic;
  final String? fotoUrl;
  final DateTime? createdAt;

  SpiReportItem({
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
    this.namaKolam,
    this.titikPenaatan,
    this.shift,
    this.latitude,
    this.longitude,
    this.skorKapasitasEndapan = 100,
    this.skorKondisiTanggul = 100,
    this.skorSekatBaffle = 100,
    this.skorPelimpahSpillway = 100,
    this.skorFasilitasDosing = 100,
    this.skorKualitasAirFisik = 100,
    this.skorTitikPenaatanDebit = 100,
    this.skorRambuPengaman = 100,
    this.totalScore = 100.0,
    this.kategoriIndex = 'Baik',
    this.catatan,
    this.tindakanPerbaikan,
    this.pic,
    this.fotoUrl,
    this.createdAt,
  });

  factory SpiReportItem.fromJson(Map<String, dynamic> json) {
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

    return SpiReportItem(
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
      namaKolam: json['namaKolam']?.toString() ?? json['NamaKolam']?.toString(),
      titikPenaatan: json['titikPenaatan']?.toString() ?? json['TitikPenaatan']?.toString(),
      shift: json['shift']?.toString() ?? json['Shift']?.toString(),
      latitude: json['latitude']?.toString() ?? json['Latitude']?.toString(),
      longitude: json['longitude']?.toString() ?? json['Longitude']?.toString(),
      skorKapasitasEndapan: parseScore(json['skorKapasitasEndapan'] ?? json['SkorKapasitasEndapan']),
      skorKondisiTanggul: parseScore(json['skorKondisiTanggul'] ?? json['SkorKondisiTanggul']),
      skorSekatBaffle: parseScore(json['skorSekatBaffle'] ?? json['SkorSekatBaffle']),
      skorPelimpahSpillway: parseScore(json['skorPelimpahSpillway'] ?? json['SkorPelimpahSpillway']),
      skorFasilitasDosing: parseScore(json['skorFasilitasDosing'] ?? json['SkorFasilitasDosing']),
      skorKualitasAirFisik: parseScore(json['skorKualitasAirFisik'] ?? json['SkorKualitasAirFisik']),
      skorTitikPenaatanDebit: parseScore(json['skorTitikPenaatanDebit'] ?? json['SkorTitikPenaatanDebit']),
      skorRambuPengaman: parseScore(json['skorRambuPengaman'] ?? json['SkorRambuPengaman']),
      totalScore: parseTotal(json['totalScore'] ?? json['TotalScore']),
      kategoriIndex: json['kategoriIndex']?.toString() ?? json['KategoriIndex']?.toString() ?? 'Baik',
      catatan: json['catatan']?.toString() ?? json['Catatan']?.toString(),
      tindakanPerbaikan: json['tindakanPerbaikan']?.toString() ?? json['TindakanPerbaikan']?.toString(),
      pic: json['pic']?.toString() ?? json['Pic']?.toString(),
      fotoUrl: json['fotoUrl']?.toString() ?? json['FotoUrl']?.toString(),
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
    'namaKolam': namaKolam,
    'titikPenaatan': titikPenaatan,
    'shift': shift,
    'latitude': latitude,
    'longitude': longitude,
    'skorKapasitasEndapan': skorKapasitasEndapan,
    'skorKondisiTanggul': skorKondisiTanggul,
    'skorSekatBaffle': skorSekatBaffle,
    'skorPelimpahSpillway': skorPelimpahSpillway,
    'skorFasilitasDosing': skorFasilitasDosing,
    'skorKualitasAirFisik': skorKualitasAirFisik,
    'skorTitikPenaatanDebit': skorTitikPenaatanDebit,
    'skorRambuPengaman': skorRambuPengaman,
    'totalScore': totalScore,
    'kategoriIndex': kategoriIndex,
    'catatan': catatan,
    'tindakanPerbaikan': tindakanPerbaikan,
    'pic': pic,
    'fotoUrl': fotoUrl,
    'createdAt': createdAt?.toIso8601String(),
  };
}

class SpiSummaryStats {
  final int totalReports;
  final double avgScore;
  final int goodCount;
  final int fairCount;
  final int poorCount;

  SpiSummaryStats({
    this.totalReports = 0,
    this.avgScore = 100.0,
    this.goodCount = 0,
    this.fairCount = 0,
    this.poorCount = 0,
  });

  factory SpiSummaryStats.fromJson(Map<String, dynamic> json) {
    return SpiSummaryStats(
      totalReports: json['totalReports'] is int ? json['totalReports'] : int.tryParse(json['totalReports']?.toString() ?? '0') ?? 0,
      avgScore: (json['avgScore'] is num) ? (json['avgScore'] as num).toDouble() : double.tryParse(json['avgScore']?.toString() ?? '100.0') ?? 100.0,
      goodCount: json['goodCount'] is int ? json['goodCount'] : int.tryParse(json['goodCount']?.toString() ?? '0') ?? 0,
      fairCount: json['fairCount'] is int ? json['fairCount'] : int.tryParse(json['fairCount']?.toString() ?? '0') ?? 0,
      poorCount: json['poorCount'] is int ? json['poorCount'] : int.tryParse(json['poorCount']?.toString() ?? '0') ?? 0,
    );
  }
}

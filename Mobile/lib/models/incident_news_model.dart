class IncidentNewsModel {
  final int id;
  final String judul;
  final String konten;
  final String? gambarUrl;
  final String lokasi;
  final DateTime? tanggalKejadian;
  final String? rawTanggal;
  final String kategori;
  final String dibuatOleh;
  final DateTime? createdAt;

  IncidentNewsModel({
    required this.id,
    required this.judul,
    required this.konten,
    this.gambarUrl,
    required this.lokasi,
    this.tanggalKejadian,
    this.rawTanggal,
    required this.kategori,
    required this.dibuatOleh,
    this.createdAt,
  });

  factory IncidentNewsModel.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    final tglStr = json['tanggal_kejadian']?.toString() ?? json['created_at']?.toString();
    if (tglStr != null && tglStr.isNotEmpty) {
      dt = DateTime.tryParse(tglStr);
    }

    return IncidentNewsModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      judul: json['judul']?.toString() ?? '',
      konten: json['konten']?.toString() ?? '',
      gambarUrl: json['gambar_url']?.toString(),
      lokasi: json['lokasi']?.toString() ?? 'Area Operasional',
      tanggalKejadian: dt,
      rawTanggal: tglStr,
      kategori: json['kategori']?.toString() ?? 'Safety Alert',
      dibuatOleh: json['dibuat_oleh']?.toString() ?? 'HSE Team',
      createdAt: dt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'judul': judul,
      'konten': konten,
      'gambar_url': gambarUrl,
      'lokasi': lokasi,
      'tanggal_kejadian': rawTanggal,
      'kategori': kategori,
      'dibuat_oleh': dibuatOleh,
      'created_at': rawTanggal,
    };
  }
}

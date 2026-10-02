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
  final bool isBanner;
  final bool isUpdate;
  final int bannerUrutan;
  final String? tags;

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
    this.isBanner = false,
    this.isUpdate = true,
    this.bannerUrutan = 0,
    this.tags,
  });

  factory IncidentNewsModel.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    final tglStr = json['tanggal_kejadian']?.toString() ?? json['created_at']?.toString();
    if (tglStr != null && tglStr.isNotEmpty) {
      dt = DateTime.tryParse(tglStr);
    }

    final isBannerRaw = json['is_banner'];
    final bool isBanner = isBannerRaw is bool
        ? isBannerRaw
        : (isBannerRaw?.toString() == '1' || isBannerRaw?.toString().toLowerCase() == 'true');

    final isUpdateRaw = json['is_update'];
    final bool isUpdate = isUpdateRaw is bool
        ? isUpdateRaw
        : (isUpdateRaw == null || isUpdateRaw.toString() == '1' || isUpdateRaw.toString().toLowerCase() == 'true');

    return IncidentNewsModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      judul: json['judul']?.toString() ?? '',
      konten: json['konten']?.toString() ?? '',
      gambarUrl: json['gambar_url']?.toString(),
      lokasi: json['lokasi']?.toString() ?? 'Area Operasional',
      tanggalKejadian: dt,
      rawTanggal: tglStr,
      kategori: json['kategori']?.toString() ?? 'Near Miss',
      dibuatOleh: json['dibuat_oleh']?.toString() ?? 'HSE Team',
      createdAt: dt,
      isBanner: isBanner,
      isUpdate: isUpdate,
      bannerUrutan: (json['banner_urutan'] as num?)?.toInt() ?? 0,
      tags: json['tags']?.toString(),
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
      'is_banner': isBanner,
      'banner_urutan': bannerUrutan,
      'tags': tags,
    };
  }
}

class PopupAdModel {
  final bool status;
  final bool hasAd;
  final String? message;
  final PopupAdData? data;
  final int totalAds;

  PopupAdModel({
    required this.status,
    required this.hasAd,
    this.message,
    this.data,
    this.totalAds = 0,
  });

  factory PopupAdModel.fromJson(Map<String, dynamic> json) {
    return PopupAdModel(
      status: json['status'] == true,
      hasAd: json['has_ad'] == true || json['hasAd'] == true,
      message: json['message']?.toString(),
      data: json['data'] != null && json['data'] is Map<String, dynamic>
          ? PopupAdData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      totalAds: json['total_ads'] is int
          ? json['total_ads'] as int
          : (json['totalAds'] is int ? json['totalAds'] as int : 0),
    );
  }
}

class PopupAdData {
  final String fileName;
  final String imageUrl;
  final int? fileSizeBytes;
  final String? updatedAt;

  PopupAdData({
    required this.fileName,
    required this.imageUrl,
    this.fileSizeBytes,
    this.updatedAt,
  });

  factory PopupAdData.fromJson(Map<String, dynamic> json) {
    return PopupAdData(
      fileName: (json['fileName'] ?? json['file_name'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'] ?? '').toString(),
      fileSizeBytes: json['fileSizeBytes'] is int
          ? json['fileSizeBytes'] as int
          : (json['file_size_bytes'] is int ? json['file_size_bytes'] as int : null),
      updatedAt: (json['updatedAt'] ?? json['updated_at'])?.toString(),
    );
  }
}

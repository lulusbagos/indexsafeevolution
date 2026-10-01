class EnumBridgeModel {
  int? id;
  String? flag;
  int? primaryId;
  int? secondaryId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  EnumBridgeModel({
    this.id,
    this.flag,
    this.primaryId,
    this.secondaryId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  EnumBridgeModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    flag = json['flag'];
    primaryId = json['primary_id'];
    secondaryId = json['secondary_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    deletedAt = json['deleted_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['flag'] = flag;
    data['primary_id'] = primaryId;
    data['secondary_id'] = secondaryId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['deleted_at'] = deletedAt;
    return data;
  }
}

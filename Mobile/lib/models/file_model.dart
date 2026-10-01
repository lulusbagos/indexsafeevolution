class FileModel {
  int? id;
  String? name;
  String? type;
  String? table;
  String? category;
  int? pointId;
  int? syncId;
  int? tranId;
  int? detailId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  FileModel({
    this.id,
    this.name,
    this.type,
    this.table,
    this.category,
    this.pointId,
    this.syncId,
    this.tranId,
    this.detailId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  FileModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    type = json['type'];
    table = json['table'];
    category = json['category'];
    pointId = json['point_id'];
    syncId = json['sync_id'];
    tranId = json['tran_id'];
    detailId = json['detail_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    deletedAt = json['deleted_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['type'] = type;
    data['table'] = table;
    data['category'] = category;
    data['point_id'] = pointId;
    data['sync_id'] = syncId;
    data['tran_id'] = tranId;
    data['detail_id'] = detailId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['deleted_at'] = deletedAt;
    return data;
  }
}

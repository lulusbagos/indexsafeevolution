class InspectDetailModel {
  int? id;
  String? name;
  String? type;
  String? flag;
  int? level;
  int? yesno;
  String? remark;
  String? image;
  String? video;
  int? status;
  int? repair;
  String? repairRemark;
  String? repairImage;
  String? repairVideo;
  int? locationId;
  int? tranId;
  int? pointId;
  int? refId;
  int? syncId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  InspectDetailModel({
    this.id,
    this.name,
    this.type,
    this.flag,
    this.level,
    this.yesno,
    this.remark,
    this.image,
    this.video,
    this.status,
    this.repair,
    this.repairRemark,
    this.repairImage,
    this.repairVideo,
    this.locationId,
    this.tranId,
    this.pointId,
    this.refId,
    this.syncId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  InspectDetailModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    type = json['type'];
    flag = json['flag'];
    level = json['level'];
    yesno = json['yesno'];
    remark = json['remark'];
    image = json['image'];
    video = json['video'];
    status = json['status'];
    repair = json['repair'];
    repairRemark = json['repair_remark'];
    repairImage = json['repair_image'];
    repairVideo = json['repair_video'];
    locationId = json['location_id'];
    tranId = json['tran_id'];
    pointId = json['point_id'];
    refId = json['ref_id'];
    syncId = json['sync_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    deletedAt = json['deleted_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['type'] = type;
    data['flag'] = flag;
    data['level'] = level;
    data['yesno'] = yesno;
    data['remark'] = remark;
    data['image'] = image;
    data['video'] = video;
    data['status'] = status;
    data['repair'] = repair;
    data['repair_remark'] = repairRemark;
    data['repair_image'] = repairImage;
    data['repair_video'] = repairVideo;
    data['location_id'] = locationId;
    data['tran_id'] = tranId;
    data['point_id'] = pointId;
    data['ref_id'] = refId;
    data['sync_id'] = syncId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['deleted_at'] = deletedAt;
    return data;
  }
}

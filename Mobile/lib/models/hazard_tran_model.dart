class HazardTrnModel {
  int? id;
  String? code;
  String? title;
  int? areaId;
  int? locationId;
  String? locationDetail;
  String? date;
  String? time;
  int? hazardId;
  int? hazardTypeId;
  int? hazardSubtypeId;
  int? hazardDangerId;
  String? remark;
  String? image;
  String? video;
  int? status;
  int? repair;
  String? repairRemark;
  String? repairImage;
  String? repairVideo;
  String? repairDate;
  String? repairTime;
  int? pjaId;
  int? companyId;
  int? employeeId;
  int? refId;
  int? syncId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  HazardTrnModel({
    this.id,
    this.code,
    this.title,
    this.areaId,
    this.locationId,
    this.locationDetail,
    this.date,
    this.time,
    this.hazardId,
    this.hazardTypeId,
    this.hazardSubtypeId,
    this.hazardDangerId,
    this.remark,
    this.image,
    this.video,
    this.status,
    this.repair,
    this.repairRemark,
    this.repairImage,
    this.repairVideo,
    this.repairDate,
    this.repairTime,
    this.pjaId,
    this.companyId,
    this.employeeId,
    this.refId,
    this.syncId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  HazardTrnModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    code = json['code'];
    title = json['title'];
    areaId = json['area_id'];
    locationId = json['location_id'];
    locationDetail = json['location_detail'];
    date = json['date'];
    time = json['time'];
    hazardId = json['hazard_id'];
    hazardTypeId = json['hazard_type_id'];
    hazardSubtypeId = json['hazard_subtype_id'];
    hazardDangerId = json['hazard_danger_id'];
    remark = json['remark'];
    image = json['image'];
    video = json['video'];
    status = json['status'];
    repair = json['repair'];
    repairRemark = json['repair_remark'];
    repairImage = json['repair_image'];
    repairVideo = json['repair_video'];
    repairDate = json['repair_date'];
    repairTime = json['repair_time'];
    pjaId = json['pja_id'];
    companyId = json['company_id'];
    employeeId = json['employee_id'];
    refId = json['ref_id'];
    syncId = json['sync_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    deletedAt = json['deleted_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['code'] = code;
    data['title'] = title;
    data['area_id'] = areaId;
    data['location_id'] = locationId;
    data['location_detail'] = locationDetail;
    data['date'] = date;
    data['time'] = time;
    data['hazard_id'] = hazardId;
    data['hazard_type_id'] = hazardTypeId;
    data['hazard_subtype_id'] = hazardSubtypeId;
    data['hazard_danger_id'] = hazardDangerId;
    data['remark'] = remark;
    data['image'] = image;
    data['video'] = video;
    data['status'] = status;
    data['repair'] = repair;
    data['repair_remark'] = repairRemark;
    data['repair_image'] = repairImage;
    data['repair_video'] = repairVideo;
    data['repair_date'] = repairDate;
    data['repair_time'] = repairTime;
    data['pja_id'] = pjaId;
    data['company_id'] = companyId;
    data['employee_id'] = employeeId;
    data['ref_id'] = refId;
    data['sync_id'] = syncId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['deleted_at'] = deletedAt;
    return data;
  }
}

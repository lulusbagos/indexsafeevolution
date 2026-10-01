class InspectTrnModel {
  int? id;
  String? code;
  String? title;
  int? areaId;
  int? locationId;
  String? locationDetail;
  String? date;
  String? time;
  int? inspectionId;
  int? shiftId;
  String? dangerLevel;
  String? remark;
  String? image;
  String? video;
  int? status;
  String? category;
  int? inspektor1Id;
  int? inspektor2Id;
  int? inspektor3Id;
  int? inspektor4Id;
  int? inspektor5Id;
  int? pjaId;
  int? companyId;
  int? employeeId;
  int? refId;
  int? syncId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  InspectTrnModel({
    this.id,
    this.code,
    this.title,
    this.areaId,
    this.locationId,
    this.locationDetail,
    this.date,
    this.time,
    this.inspectionId,
    this.shiftId,
    this.dangerLevel,
    this.remark,
    this.image,
    this.video,
    this.status,
    this.category,
    this.inspektor1Id,
    this.inspektor2Id,
    this.inspektor3Id,
    this.inspektor4Id,
    this.inspektor5Id,
    this.pjaId,
    this.companyId,
    this.employeeId,
    this.refId,
    this.syncId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  InspectTrnModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    code = json['code'];
    title = json['title'];
    areaId = json['area_id'];
    locationId = json['location_id'];
    locationDetail = json['location_detail'];
    date = json['date'];
    time = json['time'];
    inspectionId = json['inspection_id'];
    shiftId = json['shift_id'];
    dangerLevel = json['danger_level'];
    remark = json['remark'];
    image = json['image'];
    video = json['video'];
    status = json['status'];
    category = json['category'];
    inspektor1Id = json['inspektor1_id'];
    inspektor2Id = json['inspektor2_id'];
    inspektor3Id = json['inspektor3_id'];
    inspektor4Id = json['inspektor4_id'];
    inspektor5Id = json['inspektor5_id'];
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
    data['inspection_id'] = inspectionId;
    data['shift_id'] = shiftId;
    data['danger_level'] = dangerLevel;
    data['remark'] = remark;
    data['image'] = image;
    data['video'] = video;
    data['status'] = status;
    data['category'] = category;
    data['inspektor1_id'] = inspektor1Id;
    data['inspektor2_id'] = inspektor2Id;
    data['inspektor3_id'] = inspektor3Id;
    data['inspektor4_id'] = inspektor4Id;
    data['inspektor5_id'] = inspektor5Id;
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

class P5MTrnModel {
  int? id;
  String? code;
  String? title;
  int? areaId;
  int? locationId;
  String? locationDetail;
  String? date;
  String? time;
  int? topicId;
  String? remark;
  String? image;
  String? video;
  int? status;
  int? companyId;
  int? employeeId;
  int? refId;
  int? syncId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  P5MTrnModel({
    this.id,
    this.code,
    this.title,
    this.areaId,
    this.locationId,
    this.locationDetail,
    this.date,
    this.time,
    this.topicId,
    this.remark,
    this.image,
    this.video,
    this.status,
    this.companyId,
    this.employeeId,
    this.refId,
    this.syncId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  P5MTrnModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    code = json['code'];
    title = json['title'];
    areaId = json['area_id'];
    locationId = json['location_id'];
    locationDetail = json['location_detail'];
    date = json['date'];
    time = json['time'];
    topicId = json['topic_id'];
    remark = json['remark'];
    image = json['image'];
    video = json['video'];
    status = json['status'];
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
    data['topic_id'] = topicId;
    data['remark'] = remark;
    data['image'] = image;
    data['video'] = video;
    data['status'] = status;
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

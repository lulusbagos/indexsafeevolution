class P2HTrnModel {
  int? id;
  String? code;
  String? title;
  int? areaId;
  int? locationId;
  String? locationDetail;
  String? date;
  String? time;
  int? vehicleId;
  double? hm;
  double? km;
  String? noLambung;
  String? merek;
  String? remark;
  String? image;
  String? video;
  int? status;
  int? simper;
  int? companyId;
  int? employeeId;
  int? refId;
  int? syncId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  P2HTrnModel({
    this.id,
    this.code,
    this.title,
    this.areaId,
    this.locationId,
    this.locationDetail,
    this.date,
    this.time,
    this.vehicleId,
    this.hm,
    this.km,
    this.noLambung,
    this.merek,
    this.remark,
    this.image,
    this.video,
    this.status,
    this.simper,
    this.companyId,
    this.employeeId,
    this.refId,
    this.syncId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  P2HTrnModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    code = json['code'];
    title = json['title'];
    areaId = json['area_id'];
    locationId = json['location_id'];
    locationDetail = json['location_detail'];
    date = json['date'];
    time = json['time'];
    vehicleId = json['vehicle_id'];
    hm = json['hm'];
    km = json['km'];
    noLambung = json['no_lambung'];
    merek = json['merek'];
    remark = json['remark'];
    image = json['image'];
    video = json['video'];
    status = json['status'];
    simper = json['simper'];
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
    data['vehicle_id'] = vehicleId;
    data['hm'] = hm;
    data['km'] = km;
    data['no_lambung'] = noLambung;
    data['merek'] = merek;
    data['remark'] = remark;
    data['image'] = image;
    data['video'] = video;
    data['status'] = status;
    data['simper'] = simper;
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

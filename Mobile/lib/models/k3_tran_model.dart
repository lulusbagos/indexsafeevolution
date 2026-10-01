class K3TrnModel {
  int? id;
  String? code;
  String? title;
  int? areaId;
  int? locationId;
  String? locationDetail;
  String? date;
  String? time;
  int? inductorId;
  String? nik;
  String? birthPlace;
  String? birthDate;
  String? hireDate;
  String? depart;
  String? section;
  String? jabatan;
  String? level;
  String? remark;
  String? image;
  String? video;
  int? status;
  String? inductorSign;
  String? employeeSign;
  int? companyId;
  int? employeeId;
  int? refId;
  int? syncId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  K3TrnModel({
    this.id,
    this.code,
    this.title,
    this.areaId,
    this.locationId,
    this.locationDetail,
    this.date,
    this.time,
    this.inductorId,
    this.nik,
    this.birthPlace,
    this.birthDate,
    this.hireDate,
    this.depart,
    this.section,
    this.jabatan,
    this.level,
    this.remark,
    this.image,
    this.video,
    this.status,
    this.inductorSign,
    this.employeeSign,
    this.companyId,
    this.employeeId,
    this.refId,
    this.syncId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  K3TrnModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    code = json['code'];
    title = json['title'];
    areaId = json['area_id'];
    locationId = json['location_id'];
    locationDetail = json['location_detail'];
    date = json['date'];
    time = json['time'];
    inductorId = json['inductor_id'];
    nik = json['nik'];
    birthPlace = json['birth_place'];
    birthDate = json['birth_date'];
    hireDate = json['hire_date'];
    depart = json['depart'];
    section = json['section'];
    jabatan = json['jabatan'];
    level = json['level'];
    remark = json['remark'];
    image = json['image'];
    video = json['video'];
    status = json['status'];
    inductorSign = json['inductor_sign'];
    employeeSign = json['employee_sign'];
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
    data['inductor_id'] = inductorId;
    data['nik'] = nik;
    data['birth_place'] = birthPlace;
    data['birth_date'] = birthDate;
    data['hire_date'] = hireDate;
    data['depart'] = depart;
    data['section'] = section;
    data['jabatan'] = jabatan;
    data['level'] = level;
    data['remark'] = remark;
    data['image'] = image;
    data['video'] = video;
    data['status'] = status;
    data['inductor_sign'] = inductorSign;
    data['employee_sign'] = employeeSign;
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

class VehicleModel {
  int? id;
  String? code;
  String? name;
  String? type;
  String? ellipseCode;
  String? unit;
  String? brand;
  String? company;
  String? chassisNo;
  String? engineNo;
  String? cnType;
  String? licensePlate;
  int? year;
  String? remark;
  int? employeeId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  VehicleModel({
    this.id,
    this.code,
    this.name,
    this.type,
    this.ellipseCode,
    this.unit,
    this.brand,
    this.company,
    this.chassisNo,
    this.engineNo,
    this.cnType,
    this.licensePlate,
    this.year,
    this.remark,
    this.employeeId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  VehicleModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    code = json['code'];
    name = json['name'];
    type = json['type'];
    ellipseCode = json['ellipse_code'];
    unit = json['unit'];
    brand = json['brand'];
    company = json['company'];
    chassisNo = json['chassis_no'];
    engineNo = json['engine_no'];
    cnType = json['cn_type'];
    licensePlate = json['license_plate'];
    year = json['year'];
    remark = json['remark'];
    employeeId = json['employee_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    deletedAt = json['deleted_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['code'] = code;
    data['name'] = name;
    data['type'] = type;
    data['ellipse_code'] = ellipseCode;
    data['unit'] = unit;
    data['brand'] = brand;
    data['company'] = company;
    data['chassis_no'] = chassisNo;
    data['engine_no'] = engineNo;
    data['cn_type'] = cnType;
    data['license_plate'] = licensePlate;
    data['year'] = year;
    data['remark'] = remark;
    data['employee_id'] = employeeId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['deleted_at'] = deletedAt;
    return data;
  }
}

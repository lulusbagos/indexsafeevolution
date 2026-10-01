class ActionPlanModel {
  int? id;
  String? code;
  String? title;
  int? areaId;
  int? locationId;
  String? locationDetail;
  String? date;
  String? time;
  String? remark;
  String? image;
  String? video;
  int? status;
  int? pjaId;
  int? picId;
  String? plan;
  String? planDate;
  int? overdue;
  String? reason;
  String? action;
  String? actionDate;
  String? actionImage;
  String? actionVideo;
  String? table;
  String? category;
  int? tranId;
  int? detailId;
  int? companyId;
  int? employeeId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  ActionPlanModel({
    this.id,
    this.code,
    this.title,
    this.areaId,
    this.locationId,
    this.locationDetail,
    this.date,
    this.time,
    this.remark,
    this.image,
    this.video,
    this.status,
    this.pjaId,
    this.picId,
    this.plan,
    this.planDate,
    this.overdue,
    this.reason,
    this.action,
    this.actionDate,
    this.actionImage,
    this.actionVideo,
    this.table,
    this.category,
    this.tranId,
    this.detailId,
    this.companyId,
    this.employeeId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  ActionPlanModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    code = json['code'];
    title = json['title'];
    areaId = json['area_id'];
    locationId = json['location_id'];
    locationDetail = json['location_detail'];
    date = json['date'];
    time = json['time'];
    remark = json['remark'];
    image = json['image'];
    video = json['video'];
    status = json['status'];
    pjaId = json['pja_id'];
    picId = json['pic_id'];
    plan = json['plan'];
    planDate = json['plan_date'];
    overdue = json['overdue'];
    reason = json['reason'];
    action = json['action'];
    actionDate = json['action_date'];
    actionImage = json['action_image'];
    actionVideo = json['action_video'];
    table = json['table'];
    category = json['category'];
    tranId = json['tran_id'];
    detailId = json['detail_id'];
    companyId = json['company_id'];
    employeeId = json['employee_id'];
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
    data['remark'] = remark;
    data['image'] = image;
    data['video'] = video;
    data['status'] = status;
    data['pja_id'] = pjaId;
    data['pic_id'] = picId;
    data['plan'] = plan;
    data['plan_date'] = planDate;
    data['overdue'] = overdue;
    data['reason'] = reason;
    data['action'] = action;
    data['action_date'] = actionDate;
    data['action_image'] = actionImage;
    data['action_video'] = actionVideo;
    data['table'] = table;
    data['category'] = category;
    data['tran_id'] = tranId;
    data['detail_id'] = detailId;
    data['company_id'] = companyId;
    data['employee_id'] = employeeId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['deleted_at'] = deletedAt;
    return data;
  }
}

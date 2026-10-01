class K3Model {
  int? id;
  String? code;
  String? name;
  String? type;
  String? flag;
  int? level;
  int? yesno;
  int? refId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  K3Model({
    this.id,
    this.code,
    this.name,
    this.type,
    this.flag,
    this.level,
    this.yesno,
    this.refId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  K3Model.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    code = json['code'];
    name = json['name'];
    type = json['type'];
    flag = json['flag'];
    level = json['level'];
    yesno = json['yesno'];
    refId = json['ref_id'];
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
    data['flag'] = flag;
    data['level'] = level;
    data['yesno'] = yesno;
    data['ref_id'] = refId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['deleted_at'] = deletedAt;
    return data;
  }
}

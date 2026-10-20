class ProfileModel {
  int? id;
  String? noAcr;
  String? noNik;
  String? doh;
  String? tglAktif;
  String? klasifikasi;
  String? paybase;
  String? statpajak;
  String? tglPermanen;
  String? tglNonaktif;
  String? company;
  String? noKtp;
  String? noKk;
  String? namaLengkap;
  String? namaAlias;
  String? jk;
  String? tmpLahir;
  String? tglLahir;
  String? statNikah;
  String? wn;
  String? emailPribadi;
  String? emailKantor;
  String? hp;
  String? namaIbu;
  String? statIbu;
  String? namaAyah;
  String? statAyah;
  String? noBpjstk;
  String? noBpjskes;
  String? noBpjspensiun;
  String? noEquity;
  String? noNpwp;
  String? depart;
  String? section;
  String? posisi;
  String? jabatan;
  String? grade;
  String? level;
  String? lokker;
  String? lokterima;
  String? poh;
  int? roster;
  String? tipe;
  String? agama;
  int? usia;
  int? lamaBekerja;
  String? statTinggal;
  String? foto;
  int? targetId;
  int? userId;
  int? companyId;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  // SAP Target and Actual for current month period (1st to end of month)
  int? myHazards;
  int? myInspections;
  int? mySafetyTalks;
  int? myObservasi;
  int? myCoaching;
  int? myP5ms;
  int? targetHazardReport;
  int? targetInspeksi;
  int? targetSafetyTalk;
  int? targetObservasi;
  int? targetCoaching;
  int? targetP5m;
  int? totalTarget;
  double? complianceRate;
  String? badgeName;
  String? badgeIcon;
  String? badgeColor;
  String? kategoriPengawas;
  String? alasanTargetZero;

  // Mine Permit fields from BIMA PostgreSQL
  String? permitNomor;
  String? masaAktifPermit;
  String? permitStatus;
  bool? hasPermit;
  String? qrCode;

  ProfileModel({
    this.id,
    this.noAcr,
    this.noNik,
    this.doh,
    this.tglAktif,
    this.klasifikasi,
    this.paybase,
    this.statpajak,
    this.tglPermanen,
    this.tglNonaktif,
    this.company,
    this.noKtp,
    this.noKk,
    this.namaLengkap,
    this.namaAlias,
    this.jk,
    this.tmpLahir,
    this.tglLahir,
    this.statNikah,
    this.wn,
    this.emailPribadi,
    this.emailKantor,
    this.hp,
    this.namaIbu,
    this.statIbu,
    this.namaAyah,
    this.statAyah,
    this.noBpjstk,
    this.noBpjskes,
    this.noBpjspensiun,
    this.noEquity,
    this.noNpwp,
    this.depart,
    this.section,
    this.posisi,
    this.jabatan,
    this.grade,
    this.level,
    this.lokker,
    this.lokterima,
    this.poh,
    this.roster,
    this.tipe,
    this.agama,
    this.usia,
    this.lamaBekerja,
    this.statTinggal,
    this.foto,
    this.targetId,
    this.userId,
    this.companyId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.myHazards,
    this.myInspections,
    this.mySafetyTalks,
    this.myObservasi,
    this.myCoaching,
    this.myP5ms,
    this.targetHazardReport,
    this.targetInspeksi,
    this.targetSafetyTalk,
    this.targetObservasi,
    this.targetCoaching,
    this.targetP5m,
    this.totalTarget,
    this.complianceRate,
    this.badgeName,
    this.badgeIcon,
    this.badgeColor,
    this.kategoriPengawas,
    this.alasanTargetZero,
    this.permitNomor,
    this.masaAktifPermit,
    this.permitStatus,
    this.hasPermit,
    this.qrCode,
  });

  ProfileModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    noAcr = json['no_acr'];
    noNik = json['no_nik'];
    doh = json['doh'];
    tglAktif = json['tgl_aktif'];
    klasifikasi = json['klasifikasi'];
    paybase = json['paybase'];
    statpajak = json['statpajak'];
    tglPermanen = json['tgl_permanen'];
    tglNonaktif = json['tgl_nonaktif'];
    company = json['company'];
    noKtp = json['no_ktp'];
    noKk = json['no_kk'];
    namaLengkap = json['nama_lengkap'];
    namaAlias = json['nama_alias'];
    jk = json['jk'];
    tmpLahir = json['tmp_lahir'];
    tglLahir = json['tgl_lahir'];
    statNikah = json['stat_nikah'];
    wn = json['wn'];
    emailPribadi = json['email_pribadi'];
    emailKantor = json['email_kantor'];
    hp = json['hp'];
    namaIbu = json['nama_ibu'];
    statIbu = json['stat_ibu'];
    namaAyah = json['nama_ayah'];
    statAyah = json['stat_ayah'];
    noBpjstk = json['no_bpjstk'];
    noBpjskes = json['no_bpjskes'];
    noBpjspensiun = json['no_bpjspensiun'];
    noEquity = json['no_equity'];
    noNpwp = json['no_npwp'];
    depart = json['depart'];
    section = json['section'];
    posisi = json['posisi'];
    jabatan = json['jabatan'] ?? json['nama_jabatan'] ?? json['job_title'];
    grade = json['grade'];
    level = json['level'];
    lokker = json['lokker'];
    lokterima = json['lokterima'];
    poh = json['poh'];
    roster = json['roster'];
    tipe = json['tipe'];
    agama = json['agama'];
    usia = json['usia'];
    lamaBekerja = json['lama_bekerja'];
    statTinggal = json['stat_tinggal'];
    foto = json['foto'];
    targetId = json['target_id'];
    userId = json['user_id'];
    companyId = json['company_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    deletedAt = json['deleted_at'];

    // SAP Target & Actual periode berjalan
    myHazards = json['my_hazards'];
    myInspections = json['my_inspections'];
    mySafetyTalks = json['my_safety_talks'];
    myObservasi = json['my_observasi'];
    myCoaching = json['my_coaching'];
    myP5ms = json['my_p5ms'];
    targetHazardReport = json['target_hazard_report'];
    targetInspeksi = json['target_inspeksi'];
    targetSafetyTalk = json['target_safety_talk'];
    targetObservasi = json['target_observasi'];
    targetCoaching = json['target_coaching'];
    targetP5m = json['target_p5m'];
    totalTarget = json['total_target'];
    complianceRate = json['compliance_rate'] != null
        ? double.tryParse(json['compliance_rate'].toString())
        : null;
    badgeName = json['badge_name'];
    badgeIcon = json['badge_icon'];
    badgeColor = json['badge_color'];
    kategoriPengawas = json['kategori_pengawas'];
    alasanTargetZero = json['alasan_target_zero'];

    // Permit fields from BIMA PostgreSQL
    permitNomor = json['permit_nomor'];
    masaAktifPermit = json['masa_aktif_permit'] ?? json['permit_berakhir_kerja'] ?? json['permit_last_expired'];
    permitStatus = json['permit_status'];
    hasPermit = json['has_permit'] ?? (permitNomor != null && permitNomor!.isNotEmpty);
    qrCode = json['qr_code'] ?? json['qr'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['no_acr'] = noAcr;
    data['no_nik'] = noNik;
    data['doh'] = doh;
    data['tgl_aktif'] = tglAktif;
    data['klasifikasi'] = klasifikasi;
    data['paybase'] = paybase;
    data['statpajak'] = statpajak;
    data['tgl_permanen'] = tglPermanen;
    data['tgl_nonaktif'] = tglNonaktif;
    data['company'] = company;
    data['no_ktp'] = noKtp;
    data['no_kk'] = noKk;
    data['nama_lengkap'] = namaLengkap;
    data['nama_alias'] = namaAlias;
    data['jk'] = jk;
    data['tmp_lahir'] = tmpLahir;
    data['tgl_lahir'] = tglLahir;
    data['stat_nikah'] = statNikah;
    data['wn'] = wn;
    data['email_pribadi'] = emailPribadi;
    data['email_kantor'] = emailKantor;
    data['hp'] = hp;
    data['nama_ibu'] = namaIbu;
    data['stat_ibu'] = statIbu;
    data['nama_ayah'] = namaAyah;
    data['stat_ayah'] = statAyah;
    data['no_bpjstk'] = noBpjstk;
    data['no_bpjskes'] = noBpjskes;
    data['no_bpjspensiun'] = noBpjspensiun;
    data['no_equity'] = noEquity;
    data['no_npwp'] = noNpwp;
    data['depart'] = depart;
    data['section'] = section;
    data['posisi'] = posisi;
    data['jabatan'] = jabatan;
    data['grade'] = grade;
    data['level'] = level;
    data['lokker'] = lokker;
    data['lokterima'] = lokterima;
    data['poh'] = poh;
    data['roster'] = roster;
    data['tipe'] = tipe;
    data['agama'] = agama;
    data['usia'] = usia;
    data['lama_bekerja'] = lamaBekerja;
    data['stat_tinggal'] = statTinggal;
    data['foto'] = foto;
    data['target_id'] = targetId;
    data['user_id'] = userId;
    data['company_id'] = companyId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['deleted_at'] = deletedAt;

    // SAP fields
    data['my_hazards'] = myHazards;
    data['my_inspections'] = myInspections;
    data['my_safety_talks'] = mySafetyTalks;
    data['my_observasi'] = myObservasi;
    data['my_coaching'] = myCoaching;
    data['my_p5ms'] = myP5ms;
    data['target_hazard_report'] = targetHazardReport;
    data['target_inspeksi'] = targetInspeksi;
    data['target_safety_talk'] = targetSafetyTalk;
    data['target_observasi'] = targetObservasi;
    data['target_coaching'] = targetCoaching;
    data['target_p5m'] = targetP5m;
    data['total_target'] = totalTarget;
    data['compliance_rate'] = complianceRate;
    data['badge_name'] = badgeName;
    data['badge_icon'] = badgeIcon;
    data['badge_color'] = badgeColor;
    data['kategori_pengawas'] = kategoriPengawas;
    data['alasan_target_zero'] = alasanTargetZero;

    // Permit fields
    data['permit_nomor'] = permitNomor;
    data['masa_aktif_permit'] = masaAktifPermit;
    data['permit_status'] = permitStatus;
    data['has_permit'] = hasPermit;
    data['qr_code'] = qrCode;
    return data;
  }
}

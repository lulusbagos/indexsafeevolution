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
  String? kategoriPengawas;
  String? alasanTargetZero;
  int? myHazardsTotal;
  int? myInspectionsTotal;
  int? mySafetyTalksTotal;
  int? myObservasiTotal;
  int? myCoachingTotal;
  int? myP5msTotal;
  int? totalSubmissions;
  double? complianceRate;
  String? badgeName;
  String? badgeIcon;
  String? badgeColor;
  bool? isMyWeekCompliant;
  int? myTotalWeek;
  int? myWeeklyTarget;
  String? userDeptName;
  int? userDeptRank;
  int? userDeptTotalCount;
  double? userDeptMtdRate;
  int? userEmpDeptRank;
  int? userEmpDeptTotalCount;
  int? userEmpCompanyRank;
  int? userEmpCompanyTotalCount;

  // BIMA PostgreSQL Data
  bool? hasPermit;
  String? permitNomor;
  String? permitStatus;
  bool? isPermitPrinted;
  String? rawPermitStatus;
  String? permitLastExpired;
  String? permitBerakhirKerja;
  bool? isPermitActive;
  bool? hasSimper;
  String? simperNomor;
  String? simperStatus;
  bool? isSimperPrinted;
  String? rawSimperStatus;
  String? jenisSimper;
  String? simperExpiredDate;
  String? simperMasaBerlaku;
  String? simperJenisSim;
  String? simperNomorSim;
  bool? isSimperActive;

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
    this.kategoriPengawas,
    this.alasanTargetZero,
    this.myHazardsTotal,
    this.myInspectionsTotal,
    this.mySafetyTalksTotal,
    this.myObservasiTotal,
    this.myCoachingTotal,
    this.myP5msTotal,
    this.totalSubmissions,
    this.complianceRate,
    this.badgeName,
    this.badgeIcon,
    this.badgeColor,
    this.isMyWeekCompliant,
    this.myTotalWeek,
    this.myWeeklyTarget,
    this.userDeptName,
    this.userDeptRank,
    this.userDeptTotalCount,
    this.userDeptMtdRate,
    this.userEmpDeptRank,
    this.userEmpDeptTotalCount,
    this.userEmpCompanyRank,
    this.userEmpCompanyTotalCount,
    this.hasPermit,
    this.permitNomor,
    this.permitStatus,
    this.isPermitPrinted,
    this.rawPermitStatus,
    this.permitLastExpired,
    this.permitBerakhirKerja,
    this.isPermitActive,
    this.hasSimper,
    this.simperNomor,
    this.simperStatus,
    this.isSimperPrinted,
    this.rawSimperStatus,
    this.jenisSimper,
    this.simperExpiredDate,
    this.simperMasaBerlaku,
    this.simperJenisSim,
    this.simperNomorSim,
    this.isSimperActive,
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
    emailPribadi = json['email_pribadi'] ?? json['email'];
    emailKantor = json['email_kantor'];
    hp = json['hp'] ?? json['phone'];
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
    myHazards = json['my_hazards'] != null ? (json['my_hazards'] as num).toInt() : null;
    myInspections = json['my_inspections'] != null ? (json['my_inspections'] as num).toInt() : null;
    mySafetyTalks = json['my_safety_talks'] != null ? (json['my_safety_talks'] as num).toInt() : null;
    myObservasi = json['my_observasi'] != null ? (json['my_observasi'] as num).toInt() : null;
    myCoaching = json['my_coaching'] != null ? (json['my_coaching'] as num).toInt() : null;
    myP5ms = json['my_p5ms'] != null ? (json['my_p5ms'] as num).toInt() : null;
    targetHazardReport = json['target_hazard_report'] != null ? (json['target_hazard_report'] as num).toInt() : null;
    targetInspeksi = json['target_inspeksi'] != null ? (json['target_inspeksi'] as num).toInt() : null;
    targetSafetyTalk = json['target_safety_talk'] != null ? (json['target_safety_talk'] as num).toInt() : null;
    targetObservasi = json['target_observasi'] != null ? (json['target_observasi'] as num).toInt() : null;
    targetCoaching = json['target_coaching'] != null ? (json['target_coaching'] as num).toInt() : null;
    targetP5m = json['target_p5m'] != null ? (json['target_p5m'] as num).toInt() : null;
    totalTarget = json['total_target'] != null ? (json['total_target'] as num).toInt() : null;
    kategoriPengawas = json['kategori_pengawas'];
    alasanTargetZero = json['alasan_target_zero'];
    myHazardsTotal = json['my_hazards_total'] != null ? (json['my_hazards_total'] as num).toInt() : null;
    myInspectionsTotal = json['my_inspections_total'] != null ? (json['my_inspections_total'] as num).toInt() : null;
    mySafetyTalksTotal = json['my_safety_talks_total'] != null ? (json['my_safety_talks_total'] as num).toInt() : null;
    myObservasiTotal = json['my_observasi_total'] != null ? (json['my_observasi_total'] as num).toInt() : null;
    myCoachingTotal = json['my_coaching_total'] != null ? (json['my_coaching_total'] as num).toInt() : null;
    myP5msTotal = json['my_p5ms_total'] != null ? (json['my_p5ms_total'] as num).toInt() : null;
    totalSubmissions = json['total_submissions'] != null ? (json['total_submissions'] as num).toInt() : null;
    complianceRate = json['compliance_rate'] != null ? (json['compliance_rate'] as num).toDouble() : null;
    badgeName = json['badge_name'];
    badgeIcon = json['badge_icon'];
    badgeColor = json['badge_color'];
    isMyWeekCompliant = json['is_my_week_compliant'] ?? true;
    myTotalWeek = json['my_total_week'] != null ? (json['my_total_week'] as num).toInt() : 0;
    myWeeklyTarget = json['my_weekly_target'] != null ? (json['my_weekly_target'] as num).toInt() : 0;
    userDeptName = json['user_dept_name'] ?? json['depart'] ?? 'SYSTEM INTEGRATIONS';
    userDeptRank = json['user_dept_rank'] != null ? (json['user_dept_rank'] as num).toInt() : 19;
    userDeptTotalCount = json['user_dept_total_count'] != null ? (json['user_dept_total_count'] as num).toInt() : 24;
    userDeptMtdRate = json['user_dept_mtd_rate'] != null ? (json['user_dept_mtd_rate'] as num).toDouble() : 0.0;
    userEmpDeptRank = json['user_emp_dept_rank'] != null ? (json['user_emp_dept_rank'] as num).toInt() : 5;
    userEmpDeptTotalCount = json['user_emp_dept_total_count'] != null ? (json['user_emp_dept_total_count'] as num).toInt() : 5;
    userEmpCompanyRank = json['user_emp_company_rank'] != null ? (json['user_emp_company_rank'] as num).toInt() : null;
    userEmpCompanyTotalCount = json['user_emp_company_total_count'] != null ? (json['user_emp_company_total_count'] as num).toInt() : null;

    hasPermit = json['has_permit'] == true;
    permitNomor = json['permit_nomor'];
    permitStatus = json['permit_status'];
    isPermitPrinted = json['is_permit_printed'] == true;
    rawPermitStatus = json['raw_permit_status'];
    permitLastExpired = json['permit_last_expired'];
    permitBerakhirKerja = json['permit_berakhir_kerja'];
    isPermitActive = json['is_permit_active'] == true;

    hasSimper = json['has_simper'] == true;
    simperNomor = json['simper_nomor'];
    simperStatus = json['simper_status'];
    isSimperPrinted = json['is_simper_printed'] == true;
    rawSimperStatus = json['raw_simper_status'];
    jenisSimper = json['jenis_simper'];
    simperExpiredDate = json['simper_expired_date'];
    simperMasaBerlaku = json['simper_masa_berlaku'];
    simperJenisSim = json['simper_jenis_sim'];
    simperNomorSim = json['simper_nomor_sim'];
    isSimperActive = json['is_simper_active'] == true;
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
    data['kategori_pengawas'] = kategoriPengawas;
    data['alasan_target_zero'] = alasanTargetZero;
    data['my_hazards_total'] = myHazardsTotal;
    data['my_inspections_total'] = myInspectionsTotal;
    data['my_safety_talks_total'] = mySafetyTalksTotal;
    data['my_observasi_total'] = myObservasiTotal;
    data['my_coaching_total'] = myCoachingTotal;
    data['my_p5ms_total'] = myP5msTotal;
    data['total_submissions'] = totalSubmissions;
    data['compliance_rate'] = complianceRate;
    data['badge_name'] = badgeName;
    data['badge_icon'] = badgeIcon;
    data['badge_color'] = badgeColor;
    data['is_my_week_compliant'] = isMyWeekCompliant;
    data['my_total_week'] = myTotalWeek;
    data['my_weekly_target'] = myWeeklyTarget;
    data['user_dept_name'] = userDeptName;
    data['user_dept_rank'] = userDeptRank;
    data['user_dept_total_count'] = userDeptTotalCount;
    data['user_dept_mtd_rate'] = userDeptMtdRate;
    data['user_emp_dept_rank'] = userEmpDeptRank;
    data['user_emp_dept_total_count'] = userEmpDeptTotalCount;
    data['user_emp_company_rank'] = userEmpCompanyRank;
    data['user_emp_company_total_count'] = userEmpCompanyTotalCount;
    data['has_permit'] = hasPermit;
    data['permit_nomor'] = permitNomor;
    data['permit_status'] = permitStatus;
    data['is_permit_printed'] = isPermitPrinted;
    data['raw_permit_status'] = rawPermitStatus;
    data['permit_last_expired'] = permitLastExpired;
    data['permit_berakhir_kerja'] = permitBerakhirKerja;
    data['is_permit_active'] = isPermitActive;
    data['has_simper'] = hasSimper;
    data['simper_nomor'] = simperNomor;
    data['simper_status'] = simperStatus;
    data['is_simper_printed'] = isSimperPrinted;
    data['raw_simper_status'] = rawSimperStatus;
    data['jenis_simper'] = jenisSimper;
    data['simper_expired_date'] = simperExpiredDate;
    data['simper_masa_berlaku'] = simperMasaBerlaku;
    data['simper_jenis_sim'] = simperJenisSim;
    data['simper_nomor_sim'] = simperNomorSim;
    data['is_simper_active'] = isSimperActive;
    return data;
  }
}

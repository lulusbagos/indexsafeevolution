import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CiParameter {
  const CiParameter(this.id, this.title, this.group, this.weight,
      {this.critical = false, this.regulatory = false});

  final String id;
  final String title;
  final String group;
  final int weight;
  final bool critical;
  final bool regulatory;
}

class CiCatalog {
  static const fci = <CiParameter>[
    CiParameter('F01', 'Lantai Front (Front Floor)', 'Parameter Front', 15),
    CiParameter('F02', 'Ruang Manuver & Spotting', 'Parameter Front', 15),
    CiParameter('F03', 'Safety Berm / Tanggul Front', 'Parameter Front', 15,
        critical: true),
    CiParameter('F04', 'Kondisi Dinding / Highwall', 'Parameter Front', 15,
        critical: true),
    CiParameter('F05', 'Drainase & Sump Front', 'Parameter Front', 10),
    CiParameter('F06', 'Kebersihan Ceceran Material', 'Parameter Front', 10),
    CiParameter(
        'F07', 'Posisi & Ketinggian Alat (Bench)', 'Parameter Front', 10),
    CiParameter('F08', 'Rambu & Penerangan Front', 'Parameter Front', 10),
  ];

  static const rci = <CiParameter>[
    CiParameter(
        'R01', 'Surfacing and Material', 'Pilar 1 • Permukaan Jalan', 20),
    CiParameter(
        'R02', 'Undulation / Corrugation', 'Pilar 1 • Permukaan Jalan', 35),
    CiParameter(
        'R03', 'Spoil (Lebar Jalan 18m)', 'Pilar 1 • Permukaan Jalan', 5),
    CiParameter('R04', 'Tinggi Tanggul 3/4 Ban',
        'Pilar 2 • Safety Berm & Fasilitas', 10),
    CiParameter('R05', 'Road Attachment (Rambu / Delineator)',
        'Pilar 2 • Safety Berm & Fasilitas', 5),
    CiParameter('R06', 'Dust (Pengendalian Debu)',
        'Pilar 2 • Safety Berm & Fasilitas', 5),
    CiParameter('R07', 'Crossfall Terbentuk (0.5% - 1%)',
        'Pilar 3 • Drainage & Perkerasan', 10),
    CiParameter('R08', 'Parit / Tali Air Terbentuk',
        'Pilar 3 • Drainage & Perkerasan', 10),
  ];

  static const dci = <CiParameter>[
    CiParameter('D01', 'Daya Dukung & Kerataan Lantai Dump',
        'Parameter Dump Condition', 15),
    CiParameter('D02', 'Tanggul Pengaman (Safety Berm)',
        'Parameter Dump Condition', 15),
    CiParameter(
        'D03', 'Kondisi Crest & Tepi Dumping', 'Parameter Dump Condition', 15),
    CiParameter(
        'D04', 'Counter Grade Lantai Dump', 'Parameter Dump Condition', 15),
    CiParameter(
        'D05', 'Drainase & Saluran Air Dump', 'Parameter Dump Condition', 10),
    CiParameter('D06', 'Penataan Spillage & Kebersihan',
        'Parameter Dump Condition', 10),
    CiParameter(
        'D07', 'Rambu K3 & Lampu Penerangan', 'Parameter Dump Condition', 10),
    CiParameter(
        'D08', 'Spotter & Pola Manuver Unit', 'Parameter Dump Condition', 10),
  ];

  static const spi = <CiParameter>[
    CiParameter(
        'S01', 'Kapasitas Endapan Sedimen', 'Parameter Sediment Pond', 15),
    CiParameter('S02', 'Kondisi & Kestabilan Tanggul Kolam',
        'Parameter Sediment Pond', 15),
    CiParameter(
        'S03', 'Sekat Baffle Pengendapan', 'Parameter Sediment Pond', 15),
    CiParameter(
        'S04', 'Saluran Pelimpah (Spillway)', 'Parameter Sediment Pond', 15),
    CiParameter(
        'S05', 'Fasilitas Dosing Bahan Kimia', 'Parameter Sediment Pond', 10),
    CiParameter('S06', 'Kualitas Air Fisik (Kekeruhan / TSS)',
        'Parameter Sediment Pond', 10),
    CiParameter('S07', 'Titik Penaatan & Alat Ukur Debit',
        'Parameter Sediment Pond', 10),
    CiParameter(
        'S08', 'Rambu K3, Pagar & Ringbuoy', 'Parameter Sediment Pond', 10),
  ];

  static List<CiParameter> forType(String type) => switch (type) {
        'RCI' => rci,
        'DCI' => dci,
        'SPI' => spi,
        _ => fci,
      };
}

class CiAnswer {
  CiAnswer(
      {required this.parameterId,
      this.score,
      this.value = '',
      this.unit = '',
      this.note = '',
      List<String>? evidencePaths,
      this.criticalFailure = false})
      : evidencePaths = evidencePaths ?? <String>[];
  final String parameterId;
  double? score;
  String value;
  String unit;
  String note;
  final List<String> evidencePaths;
  bool criticalFailure;

  Map<String, dynamic> toJson() => {
        'parameterId': parameterId,
        'score': score,
        'value': value,
        'unit': unit,
        'note': note,
        'evidencePaths': evidencePaths,
        'criticalFailure': criticalFailure
      };
  factory CiAnswer.fromJson(Map<String, dynamic> json) => CiAnswer(
      parameterId: '${json['parameterId']}',
      score: (json['score'] as num?)?.toDouble(),
      value: '${json['value'] ?? ''}',
      unit: '${json['unit'] ?? ''}',
      note: '${json['note'] ?? ''}',
      evidencePaths: List<String>.from(json['evidencePaths'] ?? const []),
      criticalFailure: json['criticalFailure'] == true);
}

class CiAssessment {
  CiAssessment(
      {required this.id,
      required this.type,
      required this.assessorName,
      required this.assessorNik,
      required this.companyId,
      required this.location,
      required this.coordinate,
      required this.assessedAt,
      required this.shift,
      required this.weather,
      required this.areaOwner,
      required this.context,
      required this.ruleVersion,
      required this.answers,
      required this.index,
      required this.band,
      required this.operationalStatus,
      required this.criticalOverride,
      required this.consequence,
      required this.likelihood,
      required this.exposure,
      required this.priority,
      required this.temporaryControls,
      required this.action,
      required this.actionOwner,
      required this.dueDate,
      required this.validUntil,
      required this.evidencePaths,
      required this.status,
      this.verificationNotes = '',
      this.verifiedAt});
  final String id,
      type,
      assessorName,
      assessorNik,
      location,
      coordinate,
      shift,
      weather,
      areaOwner,
      context,
      ruleVersion,
      band,
      operationalStatus,
      exposure,
      priority,
      temporaryControls,
      action,
      actionOwner,
      status,
      verificationNotes;
  final int? companyId;
  final DateTime assessedAt, dueDate, validUntil;
  final DateTime? verifiedAt;
  final List<CiAnswer> answers;
  final List<String> evidencePaths;
  final double index;
  final bool criticalOverride;
  final int consequence, likelihood;

  CiAssessment copyWith(
          {String? status, String? verificationNotes, DateTime? verifiedAt}) =>
      CiAssessment(
          id: id,
          type: type,
          assessorName: assessorName,
          assessorNik: assessorNik,
          companyId: companyId,
          location: location,
          coordinate: coordinate,
          assessedAt: assessedAt,
          shift: shift,
          weather: weather,
          areaOwner: areaOwner,
          context: context,
          ruleVersion: ruleVersion,
          answers: answers,
          index: index,
          band: band,
          operationalStatus: operationalStatus,
          criticalOverride: criticalOverride,
          consequence: consequence,
          likelihood: likelihood,
          exposure: exposure,
          priority: priority,
          temporaryControls: temporaryControls,
          action: action,
          actionOwner: actionOwner,
          dueDate: dueDate,
          validUntil: validUntil,
          evidencePaths: evidencePaths,
          status: status ?? this.status,
          verificationNotes: verificationNotes ?? this.verificationNotes,
          verifiedAt: verifiedAt ?? this.verifiedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'assessorName': assessorName,
        'assessorNik': assessorNik,
        'companyId': companyId,
        'location': location,
        'coordinate': coordinate,
        'assessedAt': assessedAt.toIso8601String(),
        'shift': shift,
        'weather': weather,
        'areaOwner': areaOwner,
        'context': context,
        'ruleVersion': ruleVersion,
        'answers': answers.map((e) => e.toJson()).toList(),
        'index': index,
        'band': band,
        'operationalStatus': operationalStatus,
        'criticalOverride': criticalOverride,
        'consequence': consequence,
        'likelihood': likelihood,
        'exposure': exposure,
        'priority': priority,
        'temporaryControls': temporaryControls,
        'action': action,
        'actionOwner': actionOwner,
        'dueDate': dueDate.toIso8601String(),
        'validUntil': validUntil.toIso8601String(),
        'evidencePaths': evidencePaths,
        'status': status,
        'verificationNotes': verificationNotes,
        'verifiedAt': verifiedAt?.toIso8601String()
      };
  factory CiAssessment.fromJson(Map<String, dynamic> j) => CiAssessment(
      id: '${j['id']}',
      type: '${j['type']}',
      assessorName: '${j['assessorName']}',
      assessorNik: '${j['assessorNik']}',
      companyId: j['companyId'] as int?,
      location: '${j['location']}',
      coordinate: '${j['coordinate']}',
      assessedAt: DateTime.parse('${j['assessedAt']}'),
      shift: '${j['shift']}',
      weather: '${j['weather']}',
      areaOwner: '${j['areaOwner']}',
      context: '${j['context']}',
      ruleVersion: '${j['ruleVersion']}',
      answers: (j['answers'] as List)
          .map((e) => CiAnswer.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      index: (j['index'] as num).toDouble(),
      band: '${j['band']}',
      operationalStatus: '${j['operationalStatus']}',
      criticalOverride: j['criticalOverride'] == true,
      consequence: j['consequence'] as int,
      likelihood: j['likelihood'] as int,
      exposure: '${j['exposure']}',
      priority: '${j['priority']}',
      temporaryControls: '${j['temporaryControls']}',
      action: '${j['action']}',
      actionOwner: '${j['actionOwner']}',
      dueDate: DateTime.parse('${j['dueDate']}'),
      validUntil: DateTime.parse('${j['validUntil']}'),
      evidencePaths: List<String>.from(j['evidencePaths'] ?? const []),
      status: '${j['status']}',
      verificationNotes: '${j['verificationNotes'] ?? ''}',
      verifiedAt: j['verifiedAt'] == null
          ? null
          : DateTime.tryParse('${j['verifiedAt']}'));
}

class CiRules {
  static double index(List<CiAnswer> answers, List<CiParameter> params) {
    var score = 0.0, maximum = 0.0;
    final maximumScore =
        params.isNotEmpty && params.first.id.startsWith('R') ? 4.0 : 5.0;
    for (final answer in answers) {
      if (answer.score == null) continue;
      final parameter = params.firstWhere((e) => e.id == answer.parameterId);
      score += answer.score! * parameter.weight;
      maximum += maximumScore * parameter.weight;
    }
    return maximum == 0 ? 0 : score / maximum * 100;
  }

  static String band(double value) => value >= 90
      ? 'GOOD'
      : value >= 80
          ? 'ACCEPTABLE'
          : value >= 65
              ? 'DEGRADED'
              : value >= 50
                  ? 'POOR'
                  : 'CRITICAL';
  static String status(double value, bool override) => override || value < 50
      ? 'STOP / CLOSE'
      : value < 65
          ? 'RESTRICTED'
          : value < 80
              ? 'OPEN WITH CONDITION'
              : 'READY / OPEN';
  static String priority(
      int consequence, int likelihood, String exposure, bool override) {
    final risk = consequence * likelihood +
        (exposure == 'High'
            ? 5
            : exposure == 'Medium'
                ? 2
                : 0);
    if (override || risk >= 20) return 'P1 - Immediate';
    if (risk >= 15) return 'P2 - ≤ 4 jam';
    if (risk >= 9) return 'P3 - ≤ 24 jam';
    if (risk >= 4) return 'P4 - 3–7 hari';
    return 'Monitor';
  }
}

class CiStorage {
  static const _key = 'ci_assessments_v1';
  static Future<List<CiAssessment>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => CiAssessment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      list.sort((a, b) => b.assessedAt.compareTo(a.assessedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(CiAssessment item) async {
    final list = await load();
    list.removeWhere((e) => e.id == item.id);
    list.insert(0, item);
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}

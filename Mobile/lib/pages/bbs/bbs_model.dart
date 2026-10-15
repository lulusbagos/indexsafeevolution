import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BbsObservation {
  BbsObservation({
    required this.id,
    required this.observerName,
    required this.observerNik,
    required this.observationType,
    required this.companyId,
    required this.location,
    required this.department,
    required this.observedPerson,
    required this.observedPosition,
    required this.observedAt,
    required this.category,
    required this.behaviors,
    required this.classification,
    required this.roadCondition,
    required this.weatherCondition,
    required this.trafficCondition,
    required this.triggerFactors,
    required this.riskLevel,
    required this.potentialConsequence,
    required this.immediateActions,
    required this.workerResponse,
    required this.coachingNotes,
    required this.commitment,
    required this.dueDate,
    required this.evidencePaths,
    required this.status,
    required this.followUpNotes,
  });

  final String id;
  final String observerName;
  final String observerNik;
  final String observationType;
  final int? companyId;
  final String location;
  final String department;
  final String observedPerson;
  final String observedPosition;
  final DateTime observedAt;
  final String category;
  final List<String> behaviors;
  final String classification;
  final String roadCondition;
  final String weatherCondition;
  final String trafficCondition;
  final List<String> triggerFactors;
  final String riskLevel;
  final String potentialConsequence;
  final List<String> immediateActions;
  final String workerResponse;
  final String coachingNotes;
  final String commitment;
  final DateTime? dueDate;
  final List<String> evidencePaths;
  final String status;
  final String followUpNotes;

  BbsObservation copyWith({String? status, String? followUpNotes}) {
    return BbsObservation(
      id: id,
      observerName: observerName,
      observerNik: observerNik,
      observationType: observationType,
      companyId: companyId,
      location: location,
      department: department,
      observedPerson: observedPerson,
      observedPosition: observedPosition,
      observedAt: observedAt,
      category: category,
      behaviors: behaviors,
      classification: classification,
      roadCondition: roadCondition,
      weatherCondition: weatherCondition,
      trafficCondition: trafficCondition,
      triggerFactors: triggerFactors,
      riskLevel: riskLevel,
      potentialConsequence: potentialConsequence,
      immediateActions: immediateActions,
      workerResponse: workerResponse,
      coachingNotes: coachingNotes,
      commitment: commitment,
      dueDate: dueDate,
      evidencePaths: evidencePaths,
      status: status ?? this.status,
      followUpNotes: followUpNotes ?? this.followUpNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'observerName': observerName,
        'observerNik': observerNik,
        'observationType': observationType,
        'companyId': companyId,
        'location': location,
        'department': department,
        'observedPerson': observedPerson,
        'observedPosition': observedPosition,
        'observedAt': observedAt.toIso8601String(),
        'category': category,
        'behaviors': behaviors,
        'classification': classification,
        'roadCondition': roadCondition,
        'weatherCondition': weatherCondition,
        'trafficCondition': trafficCondition,
        'triggerFactors': triggerFactors,
        'riskLevel': riskLevel,
        'potentialConsequence': potentialConsequence,
        'immediateActions': immediateActions,
        'workerResponse': workerResponse,
        'coachingNotes': coachingNotes,
        'commitment': commitment,
        'dueDate': dueDate?.toIso8601String(),
        'evidencePaths': evidencePaths,
        'status': status,
        'followUpNotes': followUpNotes,
      };

  factory BbsObservation.fromJson(Map<String, dynamic> json) {
    final legacyEvidence = json['evidencePath'] as String?;
    final evidencePaths = json['evidencePaths'] == null
        ? <String>[
            if (legacyEvidence != null && legacyEvidence.isNotEmpty)
              legacyEvidence,
          ]
        : List<String>.from(json['evidencePaths'] as List<dynamic>);
    return BbsObservation(
      id: '${json['id']}',
      observerName: '${json['observerName'] ?? '-'}',
      observerNik: '${json['observerNik'] ?? '-'}',
      observationType: '${json['observationType'] ?? 'Observasi Rutin'}',
      companyId: json['companyId'] as int?,
      location: '${json['location'] ?? '-'}',
      department: '${json['department'] ?? '-'}',
      observedPerson: '${json['observedPerson'] ?? '-'}',
      observedPosition: '${json['observedPosition'] ?? '-'}',
      observedAt: DateTime.tryParse('${json['observedAt']}') ?? DateTime.now(),
      category: '${json['category'] ?? '-'}',
      behaviors: List<String>.from(json['behaviors'] ?? const []),
      classification: '${json['classification'] ?? '-'}',
      roadCondition: '${json['roadCondition'] ?? '-'}',
      weatherCondition: '${json['weatherCondition'] ?? '-'}',
      trafficCondition: '${json['trafficCondition'] ?? '-'}',
      triggerFactors: List<String>.from(json['triggerFactors'] ?? const []),
      riskLevel: '${json['riskLevel'] ?? '-'}',
      potentialConsequence: '${json['potentialConsequence'] ?? '-'}',
      immediateActions: List<String>.from(json['immediateActions'] ?? const []),
      workerResponse: '${json['workerResponse'] ?? '-'}',
      coachingNotes: '${json['coachingNotes'] ?? '-'}',
      commitment: '${json['commitment'] ?? '-'}',
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.tryParse('${json['dueDate']}'),
      evidencePaths: evidencePaths.take(5).toList(),
      status: '${json['status'] ?? 'Open'}',
      followUpNotes: '${json['followUpNotes'] ?? ''}',
    );
  }
}

class BbsStorage {
  static const _key = 'bbs_observations_v1';

  static Future<List<BbsObservation>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      final observations = data
          .map((item) => BbsObservation.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>)))
          .toList();
      observations.sort((a, b) => b.observedAt.compareTo(a.observedAt));
      return observations;
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(BbsObservation observation) async {
    final observations = await load();
    observations.removeWhere((item) => item.id == observation.id);
    observations.insert(0, observation);
    await _write(observations);
  }

  static Future<void> update(BbsObservation observation) async {
    final observations = await load();
    final index = observations.indexWhere((item) => item.id == observation.id);
    if (index < 0) return;
    observations[index] = observation;
    await _write(observations);
  }

  static Future<void> _write(List<BbsObservation> observations) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(observations.map((item) => item.toJson()).toList()),
    );
  }
}

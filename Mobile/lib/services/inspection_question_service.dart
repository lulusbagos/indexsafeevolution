import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database.dart';
import 'api.dart';

class InspectionQuestionItem {
  final int id;
  final String key;
  final String moduleTitle;
  final String question;
  final String? guidance;
  final int orderIndex;
  final bool isActive;
  final bool isCustom;

  InspectionQuestionItem({
    required this.id,
    required this.key,
    required this.moduleTitle,
    required this.question,
    this.guidance,
    this.orderIndex = 0,
    this.isActive = true,
    this.isCustom = false,
  });

  factory InspectionQuestionItem.fromJson(Map<String, dynamic> json) {
    final rawKey = (json['key'] ?? '').toString();
    final cleanKey = rawKey.startsWith('q') && rawKey.length > 2 ? rawKey.substring(1) : rawKey;
    return InspectionQuestionItem(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      key: cleanKey.trim(),
      moduleTitle: json['moduleTitle']?.toString() ?? json['module_title']?.toString() ?? 'Inspeksi K3',
      question: json['question']?.toString() ?? '',
      guidance: json['guidance']?.toString(),
      orderIndex: json['orderIndex'] is int ? json['orderIndex'] : (int.tryParse(json['order_index']?.toString() ?? '0') ?? 0),
      isActive: json['isActive'] == true || json['is_active'] == 1 || json['is_active'] == true,
      isCustom: json['isCustom'] == true || json['is_custom'] == 1 || json['is_custom'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'key': key,
    'module_title': moduleTitle,
    'question': question,
    'guidance': guidance,
    'order_index': orderIndex,
    'is_active': isActive ? 1 : 0,
    'is_custom': isCustom ? 1 : 0,
  };
}

class InspectionQuestionService {
  InspectionQuestionService._();
  static final InspectionQuestionService instance = InspectionQuestionService._();

  static final List<InspectionQuestionItem> defaultQuestions = [
    // Modul 1: Kepatuhan & Sistem
    InspectionQuestionItem(
      id: 1,
      key: '1_1',
      moduleTitle: 'Modul 1: Kepatuhan & Sistem',
      question: 'Apakah pekerjaan yang diamati dilakukan sesuai prosedur yang berlaku?',
      orderIndex: 1,
    ),
    InspectionQuestionItem(
      id: 2,
      key: '1_2',
      moduleTitle: 'Modul 1: Kepatuhan & Sistem',
      question: 'Apakah dokumen/izin yang diperlukan tersedia dan masih berlaku?',
      orderIndex: 2,
    ),
    InspectionQuestionItem(
      id: 3,
      key: '1_3',
      moduleTitle: 'Modul 1: Kepatuhan & Sistem',
      question: 'Apakah temuan inspeksi sebelumnya sudah ditindaklanjuti?',
      orderIndex: 3,
    ),

    // Modul 2: Risiko & Keselamatan
    InspectionQuestionItem(
      id: 4,
      key: '2_1',
      moduleTitle: 'Modul 2: Risiko & Keselamatan',
      question: 'Apakah risiko utama pekerjaan telah diidentifikasi sebelum pekerjaan dilakukan?',
      orderIndex: 4,
    ),
    InspectionQuestionItem(
      id: 5,
      key: '2_2',
      moduleTitle: 'Modul 2: Risiko & Keselamatan',
      question: 'Apakah pengendali risiko kritis telah diterapkan secara efektif?',
      orderIndex: 5,
    ),
    InspectionQuestionItem(
      id: 6,
      key: '2_3',
      moduleTitle: 'Modul 2: Risiko & Keselamatan',
      question: 'Apakah pekerja memahami risiko dan langkah mitigasi saat terjadi bahaya?',
      orderIndex: 6,
    ),

    // Modul 3: Lingkungan Kerja & Housekeeping
    InspectionQuestionItem(
      id: 7,
      key: '3_1',
      moduleTitle: 'Modul 3: Lingkungan Kerja & Housekeeping',
      question: 'Apakah area kerja bersih, rapi, dan bebas dari bahaya tersandung atau terpeleset?',
      orderIndex: 7,
    ),
    InspectionQuestionItem(
      id: 8,
      key: '3_2',
      moduleTitle: 'Modul 3: Lingkungan Kerja & Housekeeping',
      question: 'Apakah pencahayaan dan ventilasi di area kerja memadai untuk aktivitas yang dilakukan?',
      orderIndex: 8,
    ),
    InspectionQuestionItem(
      id: 9,
      key: '3_3',
      moduleTitle: 'Modul 3: Lingkungan Kerja & Housekeeping',
      question: 'Apakah limbah B3 dan sampah operasional dikelola dan dipisahkan dengan benar?',
      orderIndex: 9,
    ),

    // Modul 4: Peralatan & APD
    InspectionQuestionItem(
      id: 10,
      key: '4_1',
      moduleTitle: 'Modul 4: Peralatan & APD',
      question: 'Apakah alat pelindung diri (APD) yang dipersyaratkan digunakan secara lengkap dan benar?',
      orderIndex: 10,
    ),
    InspectionQuestionItem(
      id: 11,
      key: '4_2',
      moduleTitle: 'Modul 4: Peralatan & APD',
      question: 'Apakah peralatan kerja dan unit telah diinspeksi (P2H) sebelum dioperasikan?',
      orderIndex: 11,
    ),
    InspectionQuestionItem(
      id: 12,
      key: '4_3',
      moduleTitle: 'Modul 4: Peralatan & APD',
      question: 'Apakah pengaman mesin / safety device berfungsi dengan baik tanpa modifikasi terlarang?',
      orderIndex: 12,
    ),

    // Modul 5: Monitoring & Perbaikan
    InspectionQuestionItem(
      id: 13,
      key: '5_1',
      moduleTitle: 'Modul 5: Monitoring & Perbaikan',
      question: 'Apakah pengawas melakukan interaksi keselamatan / observasi secara berkala?',
      orderIndex: 13,
    ),
    InspectionQuestionItem(
      id: 14,
      key: '5_2',
      moduleTitle: 'Modul 5: Monitoring & Perbaikan',
      question: 'Apakah temuan K3 dicatat dan ditindaklanjuti rencana perbaikannya?',
      orderIndex: 14,
    ),
    InspectionQuestionItem(
      id: 15,
      key: '5_3',
      moduleTitle: 'Modul 5: Monitoring & Perbaikan',
      question: 'Apakah tersedia bukti bahwa tindakan perbaikan telah dilakukan dan efektif?',
      orderIndex: 15,
    ),
  ];

  static final Map<String, InspectionQuestionItem> _questionCache = {
    for (var q in defaultQuestions) q.key: q,
  };

  static String normalizeKey(String rawKey) {
    var k = rawKey.trim();
    if (k.toLowerCase().startsWith('q')) {
      k = k.substring(1);
    }
    k = k.replaceAll('.', '_');
    return k;
  }

  static String getQuestionText(String rawKey) {
    final k = normalizeKey(rawKey);
    if (_questionCache.containsKey(k)) {
      return _questionCache[k]!.question;
    }
    return 'Pertanyaan Evaluasi K3 ($rawKey)';
  }

  static String getModuleTitle(String rawKey) {
    final k = normalizeKey(rawKey);
    if (_questionCache.containsKey(k)) {
      return _questionCache[k]!.moduleTitle;
    }
    if (k.startsWith('1_')) return 'Modul 1: Kepatuhan & Sistem';
    if (k.startsWith('2_')) return 'Modul 2: Risiko & Keselamatan';
    if (k.startsWith('3_')) return 'Modul 3: Lingkungan Kerja & Housekeeping';
    if (k.startsWith('4_')) return 'Modul 4: Peralatan & APD';
    if (k.startsWith('5_')) return 'Modul 5: Monitoring & Perbaikan';
    return 'Evaluasi Checkpoint K3';
  }

  Future<Database> _getDb() async {
    return await DatabaseService().database;
  }

  Future<void> _ensureLocalTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tbl_m_inspection_question (
        id INTEGER PRIMARY KEY,
        key TEXT,
        module_title TEXT,
        question TEXT,
        guidance TEXT,
        order_index INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        is_custom INTEGER DEFAULT 0
      )
    ''');
  }

  Future<List<InspectionQuestionItem>> loadQuestions({bool syncWithBackend = true}) async {
    try {
      final db = await _getDb();
      await _ensureLocalTable(db);

      // 1. Baca dari cache SQLite lokal
      final rows = await db.query(
        'tbl_m_inspection_question',
        where: 'is_active = 1',
        orderBy: 'order_index ASC, id ASC',
      );

      List<InspectionQuestionItem> list = [];
      if (rows.isNotEmpty) {
        list = rows.map((r) => InspectionQuestionItem.fromJson(r)).toList();
      } else {
        // Seed default questions ke SQLite
        final batch = db.batch();
        for (var q in defaultQuestions) {
          batch.insert(
            'tbl_m_inspection_question',
            q.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        list = List.from(defaultQuestions);
      }

      // Update in-memory cache
      for (var q in list) {
        _questionCache[q.key] = q;
      }

      // 2. Sinkronkan dengan Backend jika diminta
      if (syncWithBackend) {
        _fetchBackendQuestionsInBackground();
      }

      return list;
    } catch (e) {
      if (kDebugMode) {
        print('[InspectionQuestionService] loadQuestions error: $e');
      }
      return List.from(defaultQuestions);
    }
  }

  void _fetchBackendQuestionsInBackground() async {
    try {
      final api = ApiService();
      final response = await api.dio.get('/master/inspection/questions');
      if (response.statusCode == 200 && response.data is List) {
        final List dataList = response.data;
        final db = await _getDb();
        await _ensureLocalTable(db);

        final batch = db.batch();
        for (var item in dataList) {
          if (item is Map) {
            final q = InspectionQuestionItem.fromJson(Map<String, dynamic>.from(item));
            _questionCache[q.key] = q;
            batch.insert(
              'tbl_m_inspection_question',
              q.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      // Offline atau server belum merespon, aman abaikan
      if (kDebugMode) {
        print('[InspectionQuestionService] Background fetch warning: $e');
      }
    }
  }

  Future<InspectionQuestionItem?> createQuestion({
    required String question,
    String? moduleTitle,
    String? guidance,
    bool isCustom = true,
  }) async {
    try {
      final db = await _getDb();
      await _ensureLocalTable(db);

      final nextId = (await db.rawQuery('SELECT MAX(id) as maxId FROM tbl_m_inspection_question'))
              .first['maxId'] as int? ?? 100;
      final newId = nextId + 1;
      final key = isCustom ? 'c_$newId' : '${newId}_1';
      final cleanModule = moduleTitle ?? (isCustom ? 'Pertanyaan Kustom Lapangan' : 'Evaluasi K3');

      final newItem = InspectionQuestionItem(
        id: newId,
        key: key,
        moduleTitle: cleanModule,
        question: question.trim(),
        guidance: guidance?.trim(),
        orderIndex: newId,
        isActive: true,
        isCustom: isCustom,
      );

      await db.insert(
        'tbl_m_inspection_question',
        newItem.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _questionCache[newItem.key] = newItem;

      // Sync ke backend API jika online
      _postQuestionToBackend(newItem);

      return newItem;
    } catch (e) {
      if (kDebugMode) {
        print('[InspectionQuestionService] createQuestion error: $e');
      }
      return null;
    }
  }

  void _postQuestionToBackend(InspectionQuestionItem item) async {
    try {
      final api = ApiService();
      await api.dio.post('/master/inspection/questions', data: {
        'key': item.key,
        'moduleTitle': item.moduleTitle,
        'question': item.question,
        'guidance': item.guidance,
        'orderIndex': item.orderIndex,
        'isCustom': item.isCustom,
      });
    } catch (_) {}
  }
}

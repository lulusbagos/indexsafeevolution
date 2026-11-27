import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import '../services/api.dart';
import '../services/preference.dart';

class DocumentManagementService {
  static final DocumentManagementService instance = DocumentManagementService._();
  DocumentManagementService._();

  final ApiService _api = ApiService();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(milliseconds: 1500),
    receiveTimeout: const Duration(milliseconds: 1500),
  ));

  // Local state cache & fallback data
  List<DocumentFolderModel> _cachedFolders = [];
  List<DocumentItemModel> _cachedFiles = [];
  bool _initialized = false;

  void _initMockFallback() {
    if (_initialized && _cachedFolders.isNotEmpty) return;
    _initialized = true;

    _cachedFolders = [
      DocumentFolderModel(
        id: 1,
        name: 'SOP & Standar K3LH',
        category: 'SOP',
        department: 'HSE & OHS',
        color: '#059669',
        icon: 'security',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        filesCount: 3,
      ),
      DocumentFolderModel(
        id: 2,
        name: 'Dokumen Pengajuan & Perizinan',
        category: 'Pengajuan',
        department: 'SYSTEM INTEGRATIONS',
        color: '#2563EB',
        icon: 'assignment',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        filesCount: 3,
      ),
      DocumentFolderModel(
        id: 3,
        name: 'Kebijakan & Regulasi Tambang',
        category: 'Drive',
        department: 'MANAGEMENT',
        color: '#D97706',
        icon: 'policy',
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        filesCount: 2,
      ),
      DocumentFolderModel(
        id: 4,
        name: 'Formulir & Template Kerja',
        category: 'Drive',
        department: 'OPERATION',
        color: '#7C3AED',
        icon: 'description',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        filesCount: 1,
      ),
      DocumentFolderModel(
        id: 5,
        name: 'Dokumen Departemen IT & SI',
        category: 'Drive',
        department: 'SYSTEM INTEGRATIONS',
        color: '#0284C7',
        icon: 'folder_special',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        filesCount: 1,
      ),
    ];

    _cachedFiles = [
      DocumentItemModel(
        id: 1,
        folderId: 1,
        docNumber: 'SOP-K3-001/IDC',
        title: 'SOP Pengoperasian Alat Berat Hauling & Excavator',
        description: 'Standar operasional prosedur pengemudian unit hauling di area pit dan disposal.',
        category: 'SOP',
        fileType: 'pdf',
        fileName: 'SOP_Hauling_Excavator_v2.4.pdf',
        fileSize: 3450000,
        version: 'v2.4',
        department: 'HSE & OHS',
        company: 'PT INDEXIM COALINDO',
        uploaderNik: '24052900991',
        uploaderName: 'IRMA NOVIANA',
        approvalStatus: 'Approved',
        approverName: 'MUHAMAD ANDRYAN RASYID',
        approvedAt: DateTime.now().subtract(const Duration(days: 5)),
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      DocumentItemModel(
        id: 2,
        folderId: 1,
        docNumber: 'SOP-ENV-012/IDC',
        title: 'Pengelolaan Limbah B3 & Kolam Pengendap Limbah',
        description: 'Prosedur pembuangan dan pemantauan kualitas baku mutu air tambang.',
        category: 'SOP',
        fileType: 'pdf',
        fileName: 'SOP_Limbah_B3_v1.8.pdf',
        fileSize: 2180000,
        version: 'v1.8',
        department: 'ENVIRONMENT',
        company: 'PT INDEXIM COALINDO',
        uploaderNik: '24052900991',
        uploaderName: 'IRMA NOVIANA',
        approvalStatus: 'Approved',
        approverName: 'MUHAMAD ANDRYAN RASYID',
        approvedAt: DateTime.now().subtract(const Duration(days: 8)),
        createdAt: DateTime.now().subtract(const Duration(days: 28)),
        updatedAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
      DocumentItemModel(
        id: 3,
        folderId: 1,
        docNumber: 'WI-OHS-005/IDC',
        title: 'Instruksi Kerja Isolasi Energi (Lockout / Tagout LOTO)',
        description: 'Instruksi kerja penguncian saklar dan valve bertekanan sebelum pekerjaan mekanikal.',
        category: 'SOP',
        fileType: 'pdf',
        fileName: 'WI_LOTO_Safety_v3.0.pdf',
        fileSize: 1890000,
        version: 'v3.0',
        department: 'HSE & OHS',
        company: 'PT INDEXIM COALINDO',
        uploaderNik: '24051940986',
        uploaderName: 'LULUS BAGOS HERMAWAN',
        approvalStatus: 'Approved',
        approverName: 'IRMA NOVIANA',
        approvedAt: DateTime.now().subtract(const Duration(days: 3)),
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      DocumentItemModel(
        id: 4,
        folderId: 2,
        docNumber: 'PTW-2026-1182',
        title: 'Pengajuan Izin Kerja Panas (Hot Work) Jetty Port',
        description: 'Pengelasan rangka conveyor belt loading 3B di area Port Jetty.',
        category: 'Pengajuan',
        fileType: 'pdf',
        fileName: 'Permit_HotWork_Jetty_1182.pdf',
        fileSize: 1450000,
        version: 'v1.0',
        department: 'SYSTEM INTEGRATIONS',
        company: 'PT INDEXIM COALINDO',
        uploaderNik: '24051940986',
        uploaderName: 'LULUS BAGOS HERMAWAN',
        approvalStatus: 'Submitted',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      DocumentItemModel(
        id: 5,
        folderId: 2,
        docNumber: 'JSA-MGE-044',
        title: 'Job Safety Analysis Perbaikan Jaringan Sensor IoT',
        description: 'Pemasangan sensor getaran dan CCTV telemetry di tower pit barat.',
        category: 'Pengajuan',
        fileType: 'pdf',
        fileName: 'JSA_IoT_Tower_WestPit.pdf',
        fileSize: 1980000,
        version: 'v1.0',
        department: 'SYSTEM INTEGRATIONS',
        company: 'PT INDEXIM COALINDO',
        uploaderNik: '24051940986',
        uploaderName: 'LULUS BAGOS HERMAWAN',
        approvalStatus: 'UnderReview',
        approverName: 'IRMA NOVIANA',
        createdAt: DateTime.now().subtract(const Duration(hours: 9)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      DocumentItemModel(
        id: 6,
        folderId: 2,
        docNumber: 'SMP-2026-089',
        title: 'Permohonan Perpanjangan SIMPER Operator Grader',
        description: 'Perpanjangan izin mengemudi unit komatsu grader pit C.',
        category: 'Pengajuan',
        fileType: 'pdf',
        fileName: 'Permohonan_SIMPER_Grader.pdf',
        fileSize: 980000,
        version: 'v1.0',
        department: 'MINING OPERATION',
        company: 'PT INDEXIM COALINDO',
        uploaderNik: '24011950928',
        uploaderName: 'MUHAMMAD ALFIAN YUSTIANDA',
        approvalStatus: 'Approved',
        approverName: 'MUHAMAD ANDRYAN RASYID',
        approvedAt: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      DocumentItemModel(
        id: 7,
        folderId: 3,
        docNumber: 'REG-ESDM-1827',
        title: 'Kepmen ESDM 1827 K/30/MEM/2018 Kaidah Pertambangan',
        description: 'Acuan regulasi resmi kaidah pertambangan yang baik dan keselamatan tambang nasional.',
        category: 'Drive',
        fileType: 'pdf',
        fileName: 'Kepmen_ESDM_1827_2018.pdf',
        fileSize: 8920000,
        version: 'v1.0',
        department: 'MANAGEMENT',
        company: 'PT INDEXIM COALINDO',
        uploaderNik: '24051940986',
        uploaderName: 'LULUS BAGOS HERMAWAN',
        approvalStatus: 'Approved',
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        updatedAt: DateTime.now().subtract(const Duration(days: 45)),
      ),
      DocumentItemModel(
        id: 8,
        folderId: 3,
        docNumber: 'POL-IDC-2026',
        title: 'Kebijakan Mutu, K3 & Lingkungan Hidup PT Indexim Coalindo 2026',
        description: 'Komitmen manajemen puncak terhadap zero fatality dan keberlanjutan lingkungan.',
        category: 'Drive',
        fileType: 'pdf',
        fileName: 'Kebijakan_K3LH_IDC_2026.pdf',
        fileSize: 1250000,
        version: 'v2026.1',
        department: 'MANAGEMENT',
        company: 'PT INDEXIM COALINDO',
        uploaderNik: '24051940986',
        uploaderName: 'LULUS BAGOS HERMAWAN',
        approvalStatus: 'Approved',
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
        updatedAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
      DocumentItemModel(
        id: 9,
        folderId: 4,
        docNumber: 'FORM-OHS-09',
        title: 'Formulir Inspeksi Tematik & Audit Rutin K3 Mingguan',
        description: 'Template checklist observasi lapangan K3 dan kepatuhan APD.',
        category: 'Drive',
        fileType: 'docx',
        fileName: 'Form_Inspeksi_K3_Weekly.docx',
        fileSize: 640000,
        version: 'v1.5',
        department: 'HSE & OHS',
        company: 'PT INDEXIM COALINDO',
        uploaderNik: '24051940986',
        uploaderName: 'LULUS BAGOS HERMAWAN',
        approvalStatus: 'Approved',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      DocumentItemModel(
        id: 10,
        folderId: 5,
        docNumber: 'ARCH-SI-2026',
        title: 'Arsitektur Sistem Indexsafe Evolution Mobile & Backend',
        description: 'Spesifikasi integrasi sistem keamanan terpadu dan arsitektur database SAP.',
        category: 'Drive',
        fileType: 'pdf',
        fileName: 'Indexsafe_Architecture_2026.pdf',
        fileSize: 4320000,
        version: 'v2.0',
        department: 'SYSTEM INTEGRATIONS',
        company: 'PT INDEXIM COALINDO',
        uploaderNik: '24051940986',
        uploaderName: 'LULUS BAGOS HERMAWAN',
        approvalStatus: 'Approved',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];
  }

  List<DocumentFolderModel> get cachedFolders {
    _initMockFallback();
    return List.unmodifiable(_cachedFolders);
  }

  List<DocumentItemModel> get cachedFiles {
    _initMockFallback();
    return List.unmodifiable(_cachedFiles);
  }

  Map<String, dynamic> get cachedSummary {
    _initMockFallback();
    final totalDocs = _cachedFiles.length;
    final totalFolders = _cachedFolders.length;
    final pendingApprovals = _cachedFiles.where((d) => d.approvalStatus == 'Submitted' || d.approvalStatus == 'UnderReview').length;
    final activeSopCount = _cachedFiles.where((d) => d.category == 'SOP' && d.approvalStatus == 'Approved').length;
    final totalStorageBytes = _cachedFiles.fold<int>(0, (sum, item) => sum + item.fileSize);
    return {
      'totalDocuments': totalDocs,
      'totalFolders': totalFolders,
      'pendingApprovals': pendingApprovals,
      'activeSopCount': activeSopCount,
      'totalStorageBytes': totalStorageBytes,
      'storageFormatted': '${(totalStorageBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
      'recentDocuments': _cachedFiles.take(5).map((e) => e.toJson()).toList(),
    };
  }

  Future<Map<String, dynamic>> getSummary({String? department}) async {
    _initMockFallback();
    try {
      final base = _api.baseUrl;
      final url = '$base/api/document-management/summary${department != null ? '?department=$department' : ''}';
      final res = await _dio.get(url);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('[DocumentManagementService] getSummary fallback: $e');
    }

    final totalDocs = _cachedFiles.length;
    final totalFolders = _cachedFolders.length;
    final pendingApprovals = _cachedFiles.where((d) => d.approvalStatus == 'Submitted' || d.approvalStatus == 'UnderReview').length;
    final activeSopCount = _cachedFiles.where((d) => d.category == 'SOP' && d.approvalStatus == 'Approved').length;
    final totalStorageBytes = _cachedFiles.fold<int>(0, (sum, item) => sum + item.fileSize);

    return {
      'totalDocuments': totalDocs,
      'totalFolders': totalFolders,
      'pendingApprovals': pendingApprovals,
      'activeSopCount': activeSopCount,
      'totalStorageBytes': totalStorageBytes,
      'storageFormatted': '${(totalStorageBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
      'recentDocuments': _cachedFiles.take(5).map((e) => e.toJson()).toList(),
    };
  }

  Future<List<DocumentFolderModel>> getFolders({int? parentId, String? category, String? department}) async {
    _initMockFallback();
    try {
      final base = _api.baseUrl;
      var query = <String>[];
      if (parentId != null) query.add('parentId=$parentId');
      if (category != null && category != 'all') query.add('category=$category');
      if (department != null) query.add('department=$department');

      final url = '$base/api/document-management/folders${query.isNotEmpty ? '?${query.join('&')}' : ''}';
      final res = await _dio.get(url);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'];
        if (data is List) {
          final list = data.map((x) => DocumentFolderModel.fromJson(x as Map<String, dynamic>)).toList();
          _cachedFolders = list;
          return list;
        }
      }
    } catch (e) {
      debugPrint('[DocumentManagementService] getFolders fallback: $e');
    }

    var result = _cachedFolders.where((f) => f.parentId == parentId).toList();
    if (category != null && category != 'all') {
      result = result.where((f) => f.category.toLowerCase() == category.toLowerCase()).toList();
    }
    return result;
  }

  Future<List<DocumentItemModel>> getFiles({
    int? folderId,
    String? category,
    String? search,
    String? approvalStatus,
    String? department,
  }) async {
    _initMockFallback();
    try {
      final base = _api.baseUrl;
      var query = <String>[];
      if (folderId != null && folderId > 0) query.add('folderId=$folderId');
      if (category != null && category != 'all') query.add('category=$category');
      if (approvalStatus != null && approvalStatus != 'all') query.add('approvalStatus=$approvalStatus');
      if (search != null && search.isNotEmpty) query.add('search=${Uri.encodeComponent(search)}');
      if (department != null) query.add('department=$department');

      final url = '$base/api/document-management/files${query.isNotEmpty ? '?${query.join('&')}' : ''}';
      final res = await _dio.get(url);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'];
        if (data is List) {
          final list = data.map((x) => DocumentItemModel.fromJson(x as Map<String, dynamic>)).toList();
          return list;
        }
      }
    } catch (e) {
      debugPrint('[DocumentManagementService] getFiles fallback: $e');
    }

    var result = List<DocumentItemModel>.from(_cachedFiles);

    if (folderId != null && folderId > 0) {
      result = result.where((d) => d.folderId == folderId).toList();
    }
    if (category != null && category != 'all') {
      result = result.where((d) => d.category.toLowerCase() == category.toLowerCase()).toList();
    }
    if (approvalStatus != null && approvalStatus != 'all') {
      result = result.where((d) => d.approvalStatus.toLowerCase() == approvalStatus.toLowerCase()).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      result = result.where((d) {
        return d.title.toLowerCase().contains(s) ||
            (d.docNumber != null && d.docNumber!.toLowerCase().contains(s)) ||
            (d.fileName != null && d.fileName!.toLowerCase().contains(s)) ||
            (d.description != null && d.description!.toLowerCase().contains(s));
      }).toList();
    }

    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  List<DocumentItemModel> getLocalFiles({
    int? folderId,
    String? category,
    String? search,
    String? approvalStatus,
  }) {
    _initMockFallback();
    var result = List<DocumentItemModel>.from(_cachedFiles);
    if (folderId != null && folderId > 0) {
      result = result.where((d) => d.folderId == folderId).toList();
    }
    if (category != null && category != 'all') {
      result = result.where((d) => d.category.toLowerCase() == category.toLowerCase()).toList();
    }
    if (approvalStatus != null && approvalStatus != 'all') {
      result = result.where((d) => d.approvalStatus.toLowerCase() == approvalStatus.toLowerCase()).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      result = result.where((d) {
        return d.title.toLowerCase().contains(s) ||
            (d.docNumber != null && d.docNumber!.toLowerCase().contains(s)) ||
            (d.fileName != null && d.fileName!.toLowerCase().contains(s)) ||
            (d.description != null && d.description!.toLowerCase().contains(s));
      }).toList();
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Future<DocumentFolderModel> createFolder({
    required String name,
    int? parentId,
    String? category,
    String? department,
    String? company,
    String? color,
    String? icon,
  }) async {
    _initMockFallback();
    final profile = PreferenceService.getProfile();
    final myNik = profile?.noNik ?? '24051940986';
    final myName = profile?.namaLengkap ?? 'LULUS BAGOS HERMAWAN';
    final myDept = department ?? profile?.depart ?? 'SYSTEM INTEGRATIONS';
    final myCompany = company ?? profile?.company ?? 'PT INDEXIM COALINDO';

    final payload = {
      'parentId': parentId,
      'name': name.trim(),
      'category': category ?? 'Drive',
      'department': myDept,
      'company': myCompany,
      'color': color ?? '#3B82F6',
      'icon': icon ?? 'folder',
      'nik': myNik,
      'nama': myName,
    };

    try {
      final base = _api.baseUrl;
      final url = '$base/api/document-management/folders';
      final res = await _dio.post(url, data: payload);

      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'];
        if (data != null) {
          final newFolder = DocumentFolderModel.fromJson(data as Map<String, dynamic>);
          _cachedFolders.add(newFolder);
          return newFolder;
        }
      }
    } catch (e) {
      debugPrint('[DocumentManagementService] createFolder fallback: $e');
    }

    final newFolder = DocumentFolderModel(
      id: _cachedFolders.length + 10,
      parentId: parentId,
      name: name.trim(),
      category: category ?? 'Drive',
      department: myDept,
      company: myCompany,
      color: color ?? '#3B82F6',
      icon: icon ?? 'folder',
      createdByName: myName,
      createdAt: DateTime.now(),
      filesCount: 0,
    );
    _cachedFolders.add(newFolder);
    return newFolder;
  }

  Future<DocumentItemModel> submitPengajuan({
    required String title,
    String? docNumber,
    String? description,
    String? category,
    String? fileType,
    String? fileName,
    int? fileSize,
    int? folderId,
  }) async {
    _initMockFallback();
    final profile = PreferenceService.getProfile();
    final myNik = profile?.noNik ?? '24051940986';
    final myName = profile?.namaLengkap ?? 'LULUS BAGOS HERMAWAN';
    final myDept = profile?.depart ?? 'SYSTEM INTEGRATIONS';
    final myCompany = profile?.company ?? 'PT INDEXIM COALINDO';

    final autoNumber = docNumber ?? 'DOC-REQ-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${(100 + _cachedFiles.length)}';

    final payload = {
      'folderId': folderId ?? 2,
      'docNumber': autoNumber,
      'title': title.trim(),
      'description': description?.trim(),
      'category': category ?? 'Pengajuan',
      'fileType': fileType ?? 'pdf',
      'fileName': fileName ?? '${title.trim().replaceAll(' ', '_')}.pdf',
      'fileSize': fileSize ?? 1450000,
      'version': 'v1.0',
      'department': myDept,
      'company': myCompany,
      'uploaderNik': myNik,
      'uploaderName': myName,
    };

    try {
      final base = _api.baseUrl;
      final url = '$base/api/document-management/submit-pengajuan';
      final res = await _dio.post(url, data: payload);

      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'];
        if (data != null) {
          final newDoc = DocumentItemModel.fromJson(data as Map<String, dynamic>);
          _cachedFiles.insert(0, newDoc);
          return newDoc;
        }
      }
    } catch (e) {
      debugPrint('[DocumentManagementService] submitPengajuan fallback: $e');
    }

    final newDoc = DocumentItemModel(
      id: _cachedFiles.length + 50,
      folderId: folderId ?? 2,
      docNumber: autoNumber,
      title: title.trim(),
      description: description?.trim(),
      category: category ?? 'Pengajuan',
      fileType: fileType ?? 'pdf',
      fileName: fileName ?? '${title.trim().replaceAll(' ', '_')}.pdf',
      fileSize: fileSize ?? 1450000,
      version: 'v1.0',
      department: myDept,
      company: myCompany,
      uploaderNik: myNik,
      uploaderName: myName,
      approvalStatus: 'Submitted',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _cachedFiles.insert(0, newDoc);
    return newDoc;
  }

  Future<bool> approveDocument(int id, {String? notes}) async {
    _initMockFallback();
    final profile = PreferenceService.getProfile();
    final myNik = profile?.noNik ?? '24051940986';
    final myName = profile?.namaLengkap ?? 'LULUS BAGOS HERMAWAN';

    try {
      final base = _api.baseUrl;
      final url = '$base/api/document-management/approve';
      final res = await _dio.post(url, data: {
        'documentId': id,
        'notes': notes,
        'approverNik': myNik,
        'approverName': myName,
      });

      if (res.statusCode == 200) {
        _updateLocalStatus(id, 'Approved', myNik, myName, notes);
        return true;
      }
    } catch (e) {
      debugPrint('[DocumentManagementService] approveDocument fallback: $e');
    }

    _updateLocalStatus(id, 'Approved', myNik, myName, notes);
    return true;
  }

  Future<bool> rejectDocument(int id, {String? notes}) async {
    _initMockFallback();
    final profile = PreferenceService.getProfile();
    final myNik = profile?.noNik ?? '24051940986';
    final myName = profile?.namaLengkap ?? 'LULUS BAGOS HERMAWAN';

    try {
      final base = _api.baseUrl;
      final url = '$base/api/document-management/reject';
      final res = await _dio.post(url, data: {
        'documentId': id,
        'notes': notes,
        'approverNik': myNik,
        'approverName': myName,
      });

      if (res.statusCode == 200) {
        _updateLocalStatus(id, 'Rejected', myNik, myName, notes);
        return true;
      }
    } catch (e) {
      debugPrint('[DocumentManagementService] rejectDocument fallback: $e');
    }

    _updateLocalStatus(id, 'Rejected', myNik, myName, notes);
    return true;
  }

  void _updateLocalStatus(int id, String status, String approverNik, String approverName, String? notes) {
    final idx = _cachedFiles.indexWhere((x) => x.id == id);
    if (idx != -1) {
      final old = _cachedFiles[idx];
      _cachedFiles[idx] = DocumentItemModel(
        id: old.id,
        folderId: old.folderId,
        docNumber: old.docNumber,
        title: old.title,
        description: old.description,
        category: old.category,
        fileType: old.fileType,
        fileUrl: old.fileUrl,
        fileName: old.fileName,
        fileSize: old.fileSize,
        version: old.version,
        department: old.department,
        company: old.company,
        uploaderNik: old.uploaderNik,
        uploaderName: old.uploaderName,
        approvalStatus: status,
        approverNik: approverNik,
        approverName: approverName,
        approvalNotes: notes,
        approvedAt: DateTime.now(),
        isConfidential: old.isConfidential,
        downloadsCount: old.downloadsCount,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<bool> deleteDocument(int id) async {
    _initMockFallback();
    try {
      final base = _api.baseUrl;
      final url = '$base/api/document-management/files/$id';
      final res = await _dio.delete(url);
      if (res.statusCode == 200) {
        _cachedFiles.removeWhere((d) => d.id == id);
        return true;
      }
    } catch (e) {
      debugPrint('[DocumentManagementService] deleteDocument fallback: $e');
    }

    _cachedFiles.removeWhere((d) => d.id == id);
    return true;
  }
}

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/document_model.dart';
import '../services/api.dart';
import '../services/preference.dart';

class DocumentAccessDeniedException implements Exception {
  final String message;
  DocumentAccessDeniedException([this.message = 'Akses dibatasi sesuai hak akses akun Anda di One Evolution.']);
  @override
  String toString() => message;
}

class DocumentManagementService {
  static final DocumentManagementService instance = DocumentManagementService._();
  DocumentManagementService._();

  final ApiService _api = ApiService();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(milliseconds: 4000),
    receiveTimeout: const Duration(milliseconds: 6000),
  ));

  String? _cacheDir;
  Map<String, dynamic>? _lastUserScope;
  Map<String, dynamic>? get lastUserScope => _lastUserScope;

  List<String> _buildCandidateUrls(String path) {
    final profile = PreferenceService.getProfile();
    final userNik = profile?.noNik ?? PreferenceService.getOfflineNik() ?? '24051940986';

    String cleanPath = path.startsWith('/') ? path : '/$path';
    if (!cleanPath.contains('nik=')) {
      final sep = cleanPath.contains('?') ? '&' : '?';
      cleanPath = '$cleanPath${sep}nik=${Uri.encodeComponent(userNik)}';
    }

    final activeBase = _api.baseUrl;
    final List<String> list = [];

    // Prioritaskan selalu domain publik resmi HTTPS (apimbs.indexim.id / apimbs.idccoal.id)
    if (!list.contains('https://apimbs.indexim.id$cleanPath')) {
      list.add('https://apimbs.indexim.id$cleanPath');
    }
    if (activeBase.isNotEmpty && !list.contains('$activeBase$cleanPath')) {
      list.add('$activeBase$cleanPath');
    }
    if (!list.contains('https://apimbs.idccoal.id$cleanPath')) {
      list.add('https://apimbs.idccoal.id$cleanPath');
    }
    return list;
  }

  Map<String, String> _buildHeaders() {
    final profile = PreferenceService.getProfile();
    final userNik = profile?.noNik ?? PreferenceService.getOfflineNik() ?? '24051940986';
    final userName = profile?.namaLengkap ?? 'Karyawan';
    final token = _api.getToken;

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-User-Nik': userNik,
      'X-User-Name': userName,
    };

    if (profile?.companyId != null) {
      headers['X-Company-Id'] = profile!.companyId.toString();
    }
    if (token.isNotEmpty && !token.startsWith('offline_token_')) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<dynamic> _fetchFromCandidates(String relativePath) async {
    final candidates = _buildCandidateUrls(relativePath);
    final headers = _buildHeaders();

    for (final url in candidates) {
      try {
        final res = await _dio.get(
          url,
          options: Options(headers: headers, responseType: ResponseType.json),
        );
        if (res.statusCode == 200 && res.data != null) {
          if (res.data is Map && res.data['userScope'] != null) {
            _lastUserScope = Map<String, dynamic>.from(res.data['userScope'] as Map);
          }
          return res.data;
        }
      } on DioException catch (de) {
        if (de.response?.statusCode == 403) {
          final msg = de.response?.data is Map && de.response?.data['message'] != null
              ? de.response!.data['message'].toString()
              : 'Akses dibatasi sesuai hak akses akun Anda di One Evolution.';
          throw DocumentAccessDeniedException(msg);
        }
        continue;
      } catch (e) {
        if (e is DocumentAccessDeniedException) rethrow;
        continue;
      }
    }
    return null;
  }

  Future<String> _getLocalCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/documents_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir.path;
      return _cacheDir!;
    } catch (e) {
      debugPrint('[DocumentService] getLocalCacheDir error: $e');
      return '';
    }
  }

  String _getLocalFilePath(String dir, DocumentItemModel doc) {
    final safeName = doc.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return '$dir/doc_${doc.id}_$safeName';
  }

  Future<void> _checkLocalCache(DocumentItemModel doc) async {
    try {
      final dir = await _getLocalCacheDir();
      if (dir.isEmpty) return;
      final target = _getLocalFilePath(dir, doc);
      final file = File(target);
      if (await file.exists() && await file.length() > 0) {
        doc.isDownloaded = true;
        doc.localPath = target;
      } else {
        doc.isDownloaded = false;
        doc.localPath = null;
      }
    } catch (_) {}
  }

  /// Ringkasan total dokumen, folder, total storage dan dokumen terbaru
  Future<Map<String, dynamic>> getSummary({String? department}) async {
    try {
      final data = await _fetchFromCandidates('/api/document-management/summary');
      if (data != null && data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[DocumentService] getSummary error: $e');
    }

    return {
      'totalDocuments': 4141,
      'totalFolders': 896,
      'totalStorageBytes': 6423702050,
      'storageFormatted': '5.98 GB',
      'activeSopCount': 521,
      'jsaCount': 1556,
      'formCount': 986,
      'policyCount': 2,
      'recentDocuments': <dynamic>[],
    };
  }

  /// Mengambil daftar folder (hierarkis). Jika parentId null, ambil kategori utama PT Indexim Coalindo.
  Future<List<DocumentFolderModel>> getFolders({int? parentId}) async {
    try {
      final query = parentId != null && parentId > 0 ? '?parentId=$parentId' : '';
      final data = await _fetchFromCandidates('/api/document-management/folders$query');
      if (data != null && data['data'] is List) {
        final list = data['data'] as List;
        final res = list.map((x) => DocumentFolderModel.fromJson(x as Map<String, dynamic>)).toList();
        if (res.isNotEmpty) return res;
      }
    } catch (e) {
      debugPrint('[DocumentService] getFolders error: $e');
    }

    // Resilient fallback untuk root folder (ID 9 / PT Indexim Coalindo) dengan ID asli database ONE_DB_MITRA
    if (parentId == null || parentId == 9) {
      return [
        DocumentFolderModel(id: 11, parentId: 9, name: '01 Kebijakan (Policy)', path: 'PT Indexim Coalindo/01 Kebijakan (Policy)', color: '#0284C7', fileCount: 2),
        DocumentFolderModel(id: 12, parentId: 9, name: '02 Manual', path: 'PT Indexim Coalindo/02 Manual', color: '#0369A1', subfolderCount: 4),
        DocumentFolderModel(id: 17, parentId: 9, name: '03 HIRADC', path: 'PT Indexim Coalindo/03 HIRADC', color: '#0284C7', subfolderCount: 19, fileCount: 1),
        DocumentFolderModel(id: 96, parentId: 9, name: '04 SOP', path: 'PT Indexim Coalindo/04 SOP', color: '#0284C7', subfolderCount: 19),
        DocumentFolderModel(id: 210, parentId: 9, name: '05 IK (WI)', path: 'PT Indexim Coalindo/05 IK (WI)', color: '#0284C7', subfolderCount: 19),
        DocumentFolderModel(id: 529, parentId: 9, name: '06 JSA', path: 'PT Indexim Coalindo/06 JSA', color: '#059669', subfolderCount: 20),
        DocumentFolderModel(id: 637, parentId: 9, name: '07 Form', path: 'PT Indexim Coalindo/07 Form', color: '#D97706', subfolderCount: 20),
        DocumentFolderModel(id: 896, parentId: 9, name: '08 Internal Memo', path: 'PT Indexim Coalindo/08 Internal Memo', color: '#7C3AED', subfolderCount: 2),
        DocumentFolderModel(id: 906, parentId: 9, name: '09 Structure Organization', path: 'PT Indexim Coalindo/09 Structure Organization', color: '#E11D48', subfolderCount: 3),
        DocumentFolderModel(id: 910, parentId: 9, name: '10 Masterlist', path: 'PT Indexim Coalindo/10 Masterlist', color: '#0D9488', fileCount: 1),
      ];
    }

    return [];
  }

  /// Mengambil daftar file dokumen dalam folder terpilih secara on-demand.
  Future<List<DocumentItemModel>> getFiles({
    required int folderId,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final profile = PreferenceService.getProfile();
      final nik = profile?.noNik ?? PreferenceService.getOfflineNik() ?? '';
      final nikParam = nik.isNotEmpty ? '&nik=$nik' : '';
      final data = await _fetchFromCandidates('/api/document-management/files?folderId=$folderId&page=$page&pageSize=$pageSize$nikParam');
      if (data != null && data['data'] is List) {
        final list = data['data'] as List;
        final items = list.map((x) => DocumentItemModel.fromJson(x as Map<String, dynamic>)).toList();
        for (final doc in items) {
          await _checkLocalCache(doc);
        }
        if (items.isNotEmpty) return items;
      }
    } catch (e) {
      debugPrint('[DocumentService] getFiles error: $e');
    }

    // Resilient offline fallback untuk folder kebijakan resmi (ID 11 atau legacy 10)
    if (folderId == 11 || folderId == 10) {
      return [
        DocumentItemModel(
          id: 3331,
          folderId: folderId,
          title: 'IC Kebijakan Keselamatan Pertambangan 2021.pdf',
          fileName: 'IC Kebijakan Keselamatan Pertambangan 2021.pdf',
          filePath: 'PT Indexim Coalindo/01 Kebijakan (Policy)/IC Kebijakan Keselamatan Pertambangan 2021.pdf',
          fileUrl: 'https://oneev.indexim.id/uploads/document_management/company_1/PT%20Indexim%20Coalindo/01%20Kebijakan%20%28Policy%29/IC%20Kebijakan%20Keselamatan%20Pertambangan%202021.pdf',
          fileType: 'pdf',
          fileSize: 1159842,
          formattedSize: '1.1 MB',
        ),
        DocumentItemModel(
          id: 3332,
          folderId: folderId,
          title: 'Kebijakan Mutu Laboratorium - Signed 22 Jan 2024.pdf',
          fileName: 'Kebijakan Mutu Laboratorium - Signed 22 Jan 2024.pdf',
          filePath: 'PT Indexim Coalindo/01 Kebijakan (Policy)/Kebijakan Mutu Laboratorium - Signed 22 Jan 2024.pdf',
          fileUrl: 'https://oneev.indexim.id/uploads/document_management/company_1/PT%20Indexim%20Coalindo/01%20Kebijakan%20%28Policy%29/Kebijakan%20Mutu%20Laboratorium%20-%20Signed%2022%20Jan%202024.pdf',
          fileType: 'pdf',
          fileSize: 10775233,
          formattedSize: '10.3 MB',
        ),
      ];
    }

    return [];
  }

  /// Pencarian cepat (instant search) pada seluruh koleksi 4.100+ dokumen ONE_DB_MITRA.
  Future<List<DocumentItemModel>> searchDocuments(String query, {int limit = 40}) async {
    if (query.trim().length < 2) return [];
    try {
      final data = await _fetchFromCandidates('/api/document-management/search?q=${Uri.encodeComponent(query.trim())}&limit=$limit');
      if (data != null && data['data'] is List) {
        final list = data['data'] as List;
        final items = list.map((x) => DocumentItemModel.fromJson(x as Map<String, dynamic>)).toList();
        for (final doc in items) {
          await _checkLocalCache(doc);
        }
        return items;
      }
    } catch (e) {
      debugPrint('[DocumentService] searchDocuments error: $e');
    }
    return [];
  }

  /// Mengambil breadcrumb hierarki folder (jalur dari root hingga folder ini).
  Future<List<Map<String, dynamic>>> getBreadcrumbs(int folderId) async {
    try {
      final data = await _fetchFromCandidates('/api/document-management/breadcrumbs?folderId=$folderId');
      if (data != null && data['data'] is List) {
        return (data['data'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[DocumentService] getBreadcrumbs error: $e');
    }
    return [];
  }

  /// Download file dokumen on-demand ke local cache storage.
  /// Jika sudah ada di cache, langsung mengembalikan path lokal tanpa download ulang.
  Future<String?> downloadFile(
    DocumentItemModel doc, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await _getLocalCacheDir();
      if (dir.isEmpty) return null;

      final targetPath = _getLocalFilePath(dir, doc);
      final file = File(targetPath);

      // Jika file sudah ada dan ukuran > 0, langsung gunakan cache
      if (await file.exists() && await file.length() > 0) {
        doc.isDownloaded = true;
        doc.localPath = targetPath;
        return targetPath;
      }

      // Download file melalui endpoint backend resmi (stream/cache)
      final candidates = _buildCandidateUrls('/api/document-management/download/${doc.id}');
      final downloadDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 3),
      ));

      for (final downloadUrl in candidates) {
        try {
          await downloadDio.download(
            downloadUrl,
            targetPath,
            onReceiveProgress: onProgress,
          );

          if (await file.exists() && await file.length() > 0) {
            doc.isDownloaded = true;
            doc.localPath = targetPath;
            return targetPath;
          }
        } catch (err) {
          debugPrint('[DocumentService] download candidate $downloadUrl failed: $err');
          continue;
        }
      }

      // Fallback ke direct URL jika kandidat backend belum berhasil
      if (doc.fileUrl.isNotEmpty) {
        try {
          await downloadDio.download(
            doc.fileUrl,
            targetPath,
            onReceiveProgress: onProgress,
          );
          if (await file.exists() && await file.length() > 0) {
            doc.isDownloaded = true;
            doc.localPath = targetPath;
            return targetPath;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[DocumentService] downloadFile error: $e');
    }
    return null;
  }

  /// Buka dokumen: periksa cache lokal, download jika belum ada, lalu buka dengan viewer aplikasi native.
  Future<bool> openDocument(
    DocumentItemModel doc, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      // 1. Download atau ambil dari cache lokal
      final localPath = await downloadFile(doc, onProgress: onProgress);

      if (localPath != null && await File(localPath).exists()) {
        // 2. Buka dengan OpenFilex
        final result = await OpenFilex.open(localPath);
        if (result.type == ResultType.done) {
          return true;
        }
        debugPrint('[DocumentService] OpenFilex result: ${result.message}');
      }

      // 3. Fallback jika OpenFilex tidak menemukan app viewer default: buka via browser / url launcher
      if (doc.fileUrl.isNotEmpty) {
        final uri = Uri.parse(doc.fileUrl);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('[DocumentService] openDocument error: $e');
    }
    return false;
  }

  /// Cek apakah file sudah tersimpan di cache
  bool isFileCached(DocumentItemModel doc) {
    if (doc.localPath != null && doc.localPath!.isNotEmpty) {
      return File(doc.localPath!).existsSync();
    }
    return false;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/auth_model.dart';
import '../models/incident_news_model.dart';
import '../models/notification_item_model.dart';
import '../models/profile_model.dart';
import 'preference.dart';

class ApiService {
  // Hotspot Tethering Laptop = http://192.168.137.1:5200
  // Wi-Fi Kantor / LAN = http://192.168.130.236:5200
  // USB ADB Reverse = http://127.0.0.1:5200
  // PROD = https://indexsafeevolution.indexim.id
  static const List<String> _candidateUrls = [
    'http://127.0.0.1:5200',
    'http://192.168.137.1:5200',
    'http://192.168.130.236:5200',
  ];
  static String _activeBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5200',
  );
  String get baseUrl => _activeBaseUrl;

  /// Aplikasi web MBS SAP adalah sumber aturan bisnis dan master Observasi.
  /// REST API Indexsafe tetap dipakai untuk modul yang sudah berbasis JWT.
  final mbsWebUrl = const String.fromEnvironment(
    'MBS_WEB_URL',
    defaultValue: 'https://mbssap.indexim.id',
  );

  bool get isLocalDev =>
      baseUrl.contains('192.168.') || baseUrl.contains('127.0.0.1');
  final company = 'IC';
  late Dio dio;

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: '$_activeBaseUrl/api',
        headers: {
          'Accept': 'application/json',
          'Connection': 'Keep-Alive',
          'company': company,
        },
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        receiveDataWhenStatusError: true,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException err, ErrorInterceptorHandler handler) async {
          if (err.type == DioExceptionType.connectionError ||
              err.type == DioExceptionType.connectionTimeout ||
              (err.error != null && err.error is SocketException)) {
            for (final candidate in _candidateUrls) {
              if (candidate == _activeBaseUrl) continue;
              try {
                final options = Options(
                  method: err.requestOptions.method,
                  headers: err.requestOptions.headers,
                  contentType: err.requestOptions.contentType,
                  responseType: err.requestOptions.responseType,
                  receiveTimeout: const Duration(seconds: 6),
                  sendTimeout: const Duration(seconds: 6),
                );
                String pathOnly = err.requestOptions.path;
                if (pathOnly.startsWith('http://') || pathOnly.startsWith('https://')) {
                  pathOnly = pathOnly.replaceFirst(RegExp(r'^https?://[^/]+/api'), '');
                }
                if (!pathOnly.startsWith('/')) pathOnly = '/$pathOnly';
                final newUrl = '$candidate/api$pathOnly';
                final fallbackDio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 4)));
                final res = await fallbackDio.request(
                  newUrl,
                  data: err.requestOptions.data,
                  queryParameters: err.requestOptions.queryParameters,
                  options: options,
                );
                _activeBaseUrl = candidate;
                dio.options.baseUrl = '$_activeBaseUrl/api';
                debugPrint('[ApiService] Successfully switched activeBaseUrl to: $_activeBaseUrl');
                return handler.resolve(res);
              } catch (_) {}
            }
          }
          return handler.next(err);
        },
      ),
    );
  }

  static String? _token;
  static String? _mbsSessionCookie;
  static Future<void>? _mbsSessionRefresh;

  String get getToken {
    return _token ?? '';
  }

  set setToken(String token) {
    _token = token;
  }

  Future<String> getEmbedWebUrl({String type = 'display'}) async {
    try {
      final res = await dio.get('/config/embed-web');
      if (res.data != null && res.data is Map) {
        final data = res.data as Map;
        if (type == 'sap_report' && data['sap_report_url'] != null) {
          return data['sap_report_url'].toString();
        }
        if (type == 'global_report' && data['global_report_url'] != null) {
          return data['global_report_url'].toString();
        }
        if (data['display_url'] != null) {
          return data['display_url'].toString();
        }
        if (data['embed_url'] != null) {
          return data['embed_url'].toString();
        }
      }
    } catch (e) {
      debugPrint('[ApiService] Error fetching embed-web config: $e');
    }
    return 'https://mbssap.indexim.id/displaymobile';
  }

  Future<Either<Map, AuthModel>> register(name, email, pswd) async {
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.post('/register',
          data: json.encode(<String, dynamic>{
            'name': name,
            'email': email,
            'password': pswd,
            'password_confirmation': pswd,
          }));
      var data = AuthModel.fromJson(Map<String, dynamic>.from(res.data as Map));
      _token = data.token;
      return Right(data);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, AuthModel>> login(user, pswd) async {
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false &&
          con.contains(ConnectivityResult.ethernet) == false) {
        return const Left({'message': 'No internet access!'});
      }

      final userStr = user.toString().trim();
      final emailParam = userStr.toUpperCase().startsWith(company.toUpperCase())
          ? userStr.toUpperCase()
          : '$company$userStr';
      final nikParam = userStr.toUpperCase().startsWith(company.toUpperCase())
          ? userStr.substring(company.length)
          : userStr;

      final loginPayload = <String, dynamic>{
        'email': emailParam,
        'nik': nikParam,
        'password': pswd,
      };

      Response res;
      try {
        final loginDio = Dio(BaseOptions(
          baseUrl: '$baseUrl/api',
          headers: dio.options.headers,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 8),
        ));
        res = await loginDio.post('/login', data: json.encode(loginPayload));
      } on DioException catch (dioErr) {
        // If Wi-Fi IP is unreachable, automatically fall back to local ADB reverse bridge
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.sendTimeout ||
            dioErr.type == DioExceptionType.receiveTimeout ||
            dioErr.type == DioExceptionType.unknown) {
          final fallbackHost =
              baseUrl.contains('192.168.') ? 'http://127.0.0.1:5200' : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: '$fallbackHost/api',
            headers: dio.options.headers,
            contentType: Headers.jsonContentType,
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 5),
          ));
          res =
              await fallbackDio.post('/login', data: json.encode(loginPayload));
          dio.options.baseUrl = '$fallbackHost/api';
        } else {
          rethrow;
        }
      }

      var data = AuthModel.fromJson(Map<String, dynamic>.from(res.data as Map));
      _token = data.token;
      // Masuk juga ke MBS SAP agar master dan skenario Observasi yang dibaca
      // mobile persis berasal dari backend web resmi.
      await _loginMbsWeb(userStr, pswd.toString());
      return Right(data);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map>> resetPassword(String nik, String birthDate) async {
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false &&
          con.contains(ConnectivityResult.ethernet) == false) {
        return const Left({'message': 'No internet access!'});
      }

      final payload = <String, dynamic>{
        'nik': nik.trim(),
        'birth_date': birthDate.trim(),
      };

      Response res;
      try {
        res = await dio.post('/reset-password', data: json.encode(payload));
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown) {
          final fallbackHost =
              baseUrl.contains('192.168.') ? 'http://127.0.0.1:5200' : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: '$fallbackHost/api',
            headers: dio.options.headers,
            contentType: Headers.jsonContentType,
            connectTimeout: const Duration(seconds: 4),
          ));
          res = await fallbackDio.post('/reset-password',
              data: json.encode(payload));
          dio.options.baseUrl = '$fallbackHost/api';
        } else {
          rethrow;
        }
      }

      return Right(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map>> logout() async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.post('/logout');
      return Right(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, ProfileModel>> getProfile() async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.get('/profile');
      return Right(
          ProfileModel.fromJson(Map<String, dynamic>.from(res.data as Map)));
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map>> changeProfile(File? pict) async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.post('/profile',
          data: FormData.fromMap({
            'foto': await MultipartFile.fromFile(pict!.path),
          }));
      return Right(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map>> changePassword(oldPswd, newPswd) async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.post('/change-password',
          data: json.encode(<String, dynamic>{
            'old_password': oldPswd,
            'new_password': newPswd,
            'new_password_confirmation': newPswd,
          }));
      return Right(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map>> getMaster(name) async {
    if (_token != null && _token!.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $_token';
    } else {
      dio.options.headers.remove('Authorization');
    }
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.get('/master/$name?limit=10000');
      if (res.data is List) {
        return Right({'data': res.data});
      }
      return Right(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map>> getTran(name) async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.get('/tran/$name?limit=10000');
      return Right(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map>> getDetail(name) async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.get('/detail/$name?limit=10000');
      return Right(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map>> getAction(name) async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.get('/action/$name?limit=10000');
      return Right(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map>> scanQr(String code,
      {String? scanType, double? lat, double? lng, double? acc}) async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.post('/qr/scan',
          data: json.encode(<String, dynamic>{
            'code': code,
            'scanType': scanType ?? 'Auto',
            'latitude': lat,
            'longitude': lng,
            'accuracy': acc,
          }));
      return Right(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Map<String, int>> getNotificationCounts() async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res = await dio.get('/notifications/count');
      if (res.data is Map) {
        final m = res.data as Map;
        final unread = (m['unread_count'] as num?)?.toInt() ?? 0;
        final unactioned = (m['unactioned_count'] as num?)?.toInt() ?? 0;
        final total = (m['total_pending_count'] as num?)?.toInt() ??
            (unread + unactioned);
        return {
          'unread': unread,
          'unactioned': unactioned,
          'total': total,
        };
      }
      return {'unread': 0, 'unactioned': 0, 'total': 0};
    } catch (_) {
      try {
        var resFallback =
            await dio.get('/notifications', queryParameters: {'limit': 1});
        if (resFallback.data is Map) {
          final m = resFallback.data as Map;
          final unread = (m['unread_count'] as num?)?.toInt() ?? 0;
          final unactioned = (m['unactioned_count'] as num?)?.toInt() ?? 0;
          final total = (m['total_pending_count'] as num?)?.toInt() ??
              (unread + unactioned);
          return {
            'unread': unread,
            'unactioned': unactioned,
            'total': total,
          };
        }
      } catch (_) {}
      return {'unread': 0, 'unactioned': 0, 'total': 0};
    }
  }

  Future<Either<Map, List<NotificationItemModel>>> getNotifications(
      {int limit = 30}) async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res =
          await dio.get('/notifications', queryParameters: {'limit': limit});
      if (res.data is Map && res.data['data'] is List) {
        final list = (res.data['data'] as List)
            .map((item) => NotificationItemModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
        return Right(list);
      }
      return const Right([]);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, bool>> markNotificationRead(int id) async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res = await dio.post('/notifications/$id/read');
      return Right(res.statusCode == 200);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, bool>> markNotificationActioned(int id) async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res = await dio.post('/notifications/$id/action');
      return Right(res.statusCode == 200);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, bool>> markAllNotificationsRead() async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res = await dio.post('/notifications/read-all');
      return Right(res.statusCode == 200);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, bool>> markAllNotificationsActioned() async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res = await dio.post('/notifications/action-all');
      return Right(res.statusCode == 200);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, NotificationItemModel>> createTestNotification() async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res = await dio.post('/notifications/test');
      if (res.data is Map && res.data['data'] is Map) {
        return Right(NotificationItemModel.fromJson(
            Map<String, dynamic>.from(res.data['data'] as Map)));
      }
      return const Left({'message': 'Gagal membuat notifikasi uji coba'});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, List<IncidentNewsModel>>> getIncidents({
    int limit = 30,
    String? category,
    String? search,
    bool? isBanner,
    bool? isUpdate,
  }) async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      final params = <String, dynamic>{'limit': limit};
      if (category != null && category.isNotEmpty && category != 'Semua') {
        params['category'] = category;
      }
      if (search != null && search.isNotEmpty) {
        params['search'] = search;
      }
      if (isBanner != null) {
        params['is_banner'] = isBanner;
      }
      if (isUpdate != null) {
        params['is_update'] = isUpdate;
      }

      Response res;
      try {
        res = await dio.get('/incidents', queryParameters: params);
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost =
              baseUrl.contains('192.168.') ? 'http://127.0.0.1:5200' : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: '$fallbackHost/api',
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.get('/incidents', queryParameters: params);
        } else {
          rethrow;
        }
      }

      if (res.data is Map && res.data['data'] is List) {
        final list = (res.data['data'] as List)
            .map((item) => IncidentNewsModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
        return Right(list);
      }
      return const Right([]);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, List<IncidentNewsModel>>> getHomeBanners(
      {int limit = 5}) async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      final params = <String, dynamic>{'limit': limit};

      Response res;
      try {
        res = await dio.get('/incidents/banners', queryParameters: params);
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost =
              baseUrl.contains('192.168.') ? 'http://127.0.0.1:5200' : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: '$fallbackHost/api',
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.get('/incidents/banners',
              queryParameters: params);
        } else {
          rethrow;
        }
      }

      if (res.data is Map && res.data['data'] is List) {
        final list = (res.data['data'] as List)
            .map((item) => IncidentNewsModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
        return Right(list);
      }
      return const Right([]);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>?>> getPopupAd() async {
    try {
      Response res;
      try {
        res = await dio.get('/ads/popup');
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost =
              baseUrl.contains('192.168.') ? 'http://127.0.0.1:5200' : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: '$fallbackHost/api',
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.get('/ads/popup');
        } else {
          rethrow;
        }
      }

      if (res.data is Map) {
        final data = res.data as Map;
        final hasAd = data['has_ad'] == true;
        if (hasAd && data['data'] != null && data['data'] is Map) {
          return Right(Map<String, dynamic>.from(data['data'] as Map));
        }
      }
      return const Right(null);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    } catch (_) {
      return const Right(null);
    }
  }

  Future<Either<Map, IncidentNewsModel>> getLatestIncident() async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      Response res;
      try {
        res = await dio.get('/incidents/latest');
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost =
              baseUrl.contains('192.168.') ? 'http://127.0.0.1:5200' : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: '$fallbackHost/api',
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.get('/incidents/latest');
        } else {
          rethrow;
        }
      }

      if (res.data is Map && res.data['data'] is Map) {
        return Right(IncidentNewsModel.fromJson(
            Map<String, dynamic>.from(res.data['data'] as Map)));
      }
      return const Left({'message': 'Data insiden tidak ditemukan'});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> getRosterInfo() async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res = await dio.get('/roster');
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Format respons roster tidak valid'});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> saveRoster({
    int? id,
    required String tipeRoster,
    required String awalDinas,
    required String akhirDinas,
    String? awalCuti,
    String? akhirCuti,
    String? keterangan,
  }) async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var payload = {
        'id': id,
        'tipeRoster': tipeRoster,
        'awalDinas': awalDinas,
        'akhirDinas': akhirDinas,
        'awalCuti': awalCuti ?? akhirDinas,
        'akhirCuti': akhirCuti ?? akhirDinas,
        'keterangan': keterangan,
      };
      var res = await dio.post('/roster', data: payload);
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right(
          {'success': true, 'message': 'Roster berhasil disimpan'});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> deleteRoster(int id) async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res = await dio.delete('/roster/$id');
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right(
          {'success': true, 'message': 'Roster berhasil dihapus'});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> getSafeMapPoints(
      {int? month, int? year}) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }
      Response res;
      try {
        res = await dio.get('/api/performance/safemap', queryParameters: {
          if (month != null) 'month': month,
          if (year != null) 'year': year,
        });
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost =
              baseUrl.contains('192.168.') ? 'http://127.0.0.1:5200' : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
          ));
          res = await fallbackDio
              .get('/api/performance/safemap', queryParameters: {
            if (month != null) 'month': month,
            if (year != null) 'year': year,
          });
        } else {
          rethrow;
        }
      }
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> getDepartmentLeague({
    int? year,
    int? month,
    int? companyId,
  }) async {
    try {
      Response res;
      try {
        res = await dio.get('/performance/league', queryParameters: {
          if (month != null) 'month': month,
          if (year != null) 'year': year,
          if (companyId != null) 'companyId': companyId,
        });
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200'
              : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: '$fallbackHost/api',
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.get('/performance/league', queryParameters: {
            if (month != null) 'month': month,
            if (year != null) 'year': year,
            if (companyId != null) 'companyId': companyId,
          });
        } else {
          rethrow;
        }
      }
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> getDepartmentSquad({
    String? nik,
    String? departmentName,
    int? year,
    int? month,
    int? companyId,
  }) async {
    try {
      Response res;
      final qParams = <String, dynamic>{
        if (nik != null && nik.isNotEmpty) 'nik': nik,
        if (departmentName != null && departmentName.isNotEmpty) 'departmentName': departmentName,
        if (month != null) 'month': month,
        if (year != null) 'year': year,
        if (companyId != null) 'companyId': companyId,
      };
      try {
        res = await dio.get('/performance/department-squad', queryParameters: qParams);
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200'
              : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: '$fallbackHost/api',
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.get('/performance/department-squad', queryParameters: qParams);
        } else {
          rethrow;
        }
      }
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> getActionTracker({
    String? nik,
    String? filter,
    String? status,
    String? type,
    String? search,
    String? startDate,
    String? endDate,
    int limit = 150,
  }) async {
    try {
      Response res;
      final qParams = <String, dynamic>{
        if (nik != null && nik.isNotEmpty) 'nik': nik,
        if (filter != null && filter.isNotEmpty) 'filter': filter,
        if (status != null && status.isNotEmpty) 'status': status,
        if (type != null && type.isNotEmpty) 'type': type,
        if (search != null && search.isNotEmpty) 'search': search,
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        'limit': limit,
      };
      try {
        res = await dio.get('/performance/action-tracker', queryParameters: qParams);
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200'
              : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: '$fallbackHost/api',
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.get('/performance/action-tracker', queryParameters: qParams);
        } else {
          rethrow;
        }
      }
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> updateActionPlan({
    required int id,
    required String status,
    String? pic,
    String? nikPic,
    String? departemenPic,
    String? rencanaPerbaikan,
    String? perbaikan,
    String? photoPath,
  }) async {
    try {
      final mapData = <String, dynamic>{
        'id': id.toString(),
        'action_id': id.toString(),
        'status': status,
        if (pic != null) 'pic': pic,
        if (nikPic != null) 'nikPic': nikPic,
        if (departemenPic != null) 'departemenPic': departemenPic,
        if (rencanaPerbaikan != null) 'rencana_perbaikan': rencanaPerbaikan,
        if (perbaikan != null) 'perbaikan': perbaikan,
      };

      if (photoPath != null && photoPath.isNotEmpty) {
        mapData['repair_image'] = await MultipartFile.fromFile(
          photoPath,
          filename: 'repair_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      final formData = FormData.fromMap(mapData);
      final res = await dio.post('/action/hazard', data: formData);
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> closeHazardFromSafeMap({
    required int id,
    required String action,
    String? photoPath,
  }) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }
      var formData = FormData.fromMap({
        'id': id,
        'action': action,
        'perbaikan': action,
      });
      if (photoPath != null && photoPath.isNotEmpty) {
        formData.files.add(MapEntry(
          'foto_perbaikan',
          await MultipartFile.fromFile(photoPath),
        ));
      }
      Response res;
      try {
        res = await dio.post('/api/performance/safemap/close-hazard',
            data: formData);
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost =
              baseUrl.contains('192.168.') ? 'http://127.0.0.1:5200' : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
          ));
          res = await fallbackDio.post('/api/performance/safemap/close-hazard',
              data: formData);
        } else {
          rethrow;
        }
      }
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> getHazardHub({
    String? filter,
    String? search,
  }) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }
      final params = <String, dynamic>{};
      if (filter != null && filter.isNotEmpty) params['filter'] = filter;
      if (search != null && search.isNotEmpty) params['search'] = search;

      Response res;
      try {
        res = await dio.get('/hazard/hub', queryParameters: params);
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200/api'
              : '$baseUrl/api';
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
          ));
          res = await fallbackDio.get('/hazard/hub', queryParameters: params);
        } else {
          rethrow;
        }
      }

      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> createHazardReport(
    Map<String, dynamic> fields, {
    File? fotoTemuan,
    File? fotoPerbaikan,
  }) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }
      var formData = FormData.fromMap(fields);

      if (fotoTemuan != null && await fotoTemuan.exists()) {
        formData.files.add(MapEntry(
          'foto_temuan',
          await MultipartFile.fromFile(fotoTemuan.path),
        ));
      }
      if (fotoPerbaikan != null && await fotoPerbaikan.exists()) {
        formData.files.add(MapEntry(
          'foto_perbaikan',
          await MultipartFile.fromFile(fotoPerbaikan.path),
        ));
      }

      Response res;
      try {
        res = await dio.post('/hazard/create', data: formData);
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200/api'
              : '$baseUrl/api';
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.post('/hazard/create', data: formData);
        } else {
          rethrow;
        }
      }

      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> closeHazardDirect(
    int id,
    String tindakanPerbaikan, {
    String? closeMode,
    File? fotoPerbaikan,
  }) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }
      var formDataMap = <String, dynamic>{
        'id': id.toString(),
        'tindakan_perbaikan': tindakanPerbaikan,
        'perbaikan': tindakanPerbaikan,
        'close_note': tindakanPerbaikan,
      };
      if (closeMode != null && closeMode.isNotEmpty) {
        formDataMap['close_mode'] = closeMode;
      }
      var formData = FormData.fromMap(formDataMap);

      if (fotoPerbaikan != null && await fotoPerbaikan.exists()) {
        formData.files.add(MapEntry(
          'foto_perbaikan',
          await MultipartFile.fromFile(fotoPerbaikan.path),
        ));
      }

      Response res;
      try {
        res = await dio.post('/hazard/close', data: formData);
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200/api'
              : '$baseUrl/api';
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.post('/hazard/close', data: formData);
        } else {
          rethrow;
        }
      }

      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> reassignHazardPja(
    int id,
    String newNik,
    String newNama,
    String newDept,
    String keterangan,
  ) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }
      final payload = {
        'id': id,
        'newNik': newNik,
        'newNama': newNama,
        'newDepartemen': newDept,
        'keterangan': keterangan,
      };

      Response res;
      try {
        res = await dio.post('/hazard/reassign', data: jsonEncode(payload));
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200/api'
              : '$baseUrl/api';
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.post('/hazard/reassign',
              data: jsonEncode(payload));
        } else {
          rethrow;
        }
      }

      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> deleteHazardDirect(int id) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }

      Response res;
      try {
        res = await dio.delete('/hazard/$id');
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200/api'
              : '$baseUrl/api';
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
          ));
          res = await fallbackDio.delete('/hazard/$id');
        } else {
          rethrow;
        }
      }

      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, List<Map<String, dynamic>>>> searchPja(String query,
      {bool lintasPerusahaan = true}) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }
      final params = {
        'q': query,
        'lintasPerusahaan': lintasPerusahaan.toString(),
      };

      Response res;
      try {
        res = await dio.get('/hazard/search-pja', queryParameters: params);
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200/api'
              : '$baseUrl/api';
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
          ));
          res = await fallbackDio.get('/hazard/search-pja',
              queryParameters: params);
        } else {
          rethrow;
        }
      }

      if (res.data is Map && (res.data as Map)['data'] is List) {
        final list = ((res.data as Map)['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return Right(list);
      }
      return const Right([]);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> takeUpHazard(int id,
      {String? note}) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }
      final payload = {
        'id': id,
        'note': note ?? '',
      };

      final res = await dio.post('/hazard/take-up', data: payload);
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({'success': true});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, List<Map<String, dynamic>>>> getSafeMapHazardPoints({
    int days = 30,
    bool onlyOpen = true,
    int limit = 80,
    double? lat,
    double? lon,
  }) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }

      final params = <String, dynamic>{
        'days': days,
        'onlyOpen': onlyOpen,
        'limit': limit,
      };
      if (lat != null && lon != null) {
        params['userLat'] = lat;
        params['userLon'] = lon;
      }

      Response res;
      try {
        res = await dio.get('/performance/safemap', queryParameters: params);
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200/api'
              : '$baseUrl/api';
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.get('/performance/safemap',
              queryParameters: params);
        } else {
          rethrow;
        }
      }

      if (res.data is Map) {
        final dataMap = res.data['data'];
        if (dataMap is Map && dataMap['hazardPoints'] is List) {
          final list = (dataMap['hazardPoints'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          return Right(list);
        }
      }
      return const Right([]);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> getHazardDetailById(int id) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }

      Response res;
      try {
        res = await dio.get('/performance/safemap/hazard/$id');
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200/api'
              : '$baseUrl/api';
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.get('/performance/safemap/hazard/$id');
        } else {
          rethrow;
        }
      }

      if (res.data is Map && res.data['data'] is Map) {
        return Right(Map<String, dynamic>.from(res.data['data'] as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, List<dynamic>>> getAttendanceEvents() async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false &&
          con.contains(ConnectivityResult.ethernet) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.get('/qr/events');
      if (res.data is Map && res.data['data'] is List) {
        return Right(res.data['data'] as List<dynamic>);
      }
      return const Right([]);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> scanAttendanceQr({
    required String code,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? scanType,
  }) async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false &&
          con.contains(ConnectivityResult.ethernet) == false) {
        return const Left({'message': 'No internet access!'});
      }

      final payload = <String, dynamic>{
        'code': code.trim(),
        'scanType': scanType ?? 'Absen Acara',
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      };

      var res = await dio.post('/qr/scan', data: json.encode(payload));
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, List<dynamic>>> getAttendanceHistory() async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false &&
          con.contains(ConnectivityResult.ethernet) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.get('/qr/history');
      if (res.data is Map && res.data['data'] is List) {
        return Right(res.data['data'] as List<dynamic>);
      }
      return const Right([]);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> getMyScanPermissions() async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false &&
          con.contains(ConnectivityResult.ethernet) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.get('/qr/my-permissions');
      if (res.data is Map && res.data['data'] is Map) {
        return Right(Map<String, dynamic>.from(res.data['data'] as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> getPermitViolationMaster() async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false &&
          con.contains(ConnectivityResult.ethernet) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.get('/qr/permit/violation-master');
      if (res.data is Map && res.data['data'] is Map) {
        return Right(Map<String, dynamic>.from(res.data['data'] as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> recordPermitViolation(
      Map<String, dynamic> payload) async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false &&
          con.contains(ConnectivityResult.ethernet) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res =
          await dio.post('/qr/permit/violation', data: json.encode(payload));
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> recordPermitMovement(
      Map<String, dynamic> payload) async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false &&
          con.contains(ConnectivityResult.ethernet) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res =
          await dio.post('/qr/permit/movement', data: json.encode(payload));
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<List<String>> getMasterAreas({int? perusahaanId}) async {
    try {
      final res = await dio.get('/master/areas', queryParameters: {
        if (perusahaanId != null && perusahaanId > 0)
          'perusahaanId': perusahaanId,
      });
      if (res.data is List) {
        final list = (res.data as List)
            .map((e) =>
                (e is Map ? e['namaArea']?.toString() : e.toString()) ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        return list;
      }
    } catch (e) {
      debugPrint('[ApiService] Error fetching master areas: $e');
    }
    return [];
  }

  Dio _mbsDio() {
    final cookie = _mbsSessionCookie ?? PreferenceService.getMbsSessionCookie();
    return Dio(BaseOptions(
      baseUrl: mbsWebUrl,
      headers: {
        'Accept': 'application/json, text/html',
        if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
      },
      responseType: ResponseType.plain,
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  String _csrfToken(String html) {
    return RegExp(
          r'name="__RequestVerificationToken"[^>]*value="([^"]+)"',
        ).firstMatch(html)?.group(1) ??
        '';
  }

  String _mergeMbsCookies(String? current, List<String>? setCookies) {
    final cookies = <String, String>{};
    if (current != null) {
      for (final value in current.split(';')) {
        final pair = value.trim();
        final pos = pair.indexOf('=');
        if (pos > 0) cookies[pair.substring(0, pos)] = pair;
      }
    }
    for (final header in setCookies ?? const <String>[]) {
      final firstPart = header.split(';').first.trim();
      final pos = firstPart.indexOf('=');
      if (pos > 0) cookies[firstPart.substring(0, pos)] = firstPart;
    }
    return cookies.values.join('; ');
  }

  Future<void> _loginMbsWeb(String user, String password) async {
    try {
      final client = _mbsDio();
      final page = await client.get<String>('/');
      final initialCookie = _mergeMbsCookies(
        _mbsSessionCookie ?? PreferenceService.getMbsSessionCookie(),
        page.headers.map['set-cookie'],
      );
      final csrf = _csrfToken(page.data ?? '');
      if (page.statusCode != 200 || csrf.isEmpty) return;

      final login = await client.post<String>('/',
          options: Options(headers: {
            'Cookie': initialCookie,
            Headers.contentTypeHeader: Headers.formUrlEncodedContentType,
          }),
          data: {
            'nrp': user.trim(),
            'password': password,
            'rememberMe': 'true',
            '__RequestVerificationToken': csrf,
          });
      if (login.statusCode != 302) return;
      final merged =
          _mergeMbsCookies(initialCookie, login.headers.map['set-cookie']);
      if (merged.isEmpty) return;
      _mbsSessionCookie = merged;
      await PreferenceService.setMbsSessionCookie(merged);
    } catch (e) {
      // Kegagalan sesi web tidak membatalkan login REST/offline. Master cache
      // dan API REST dipakai sebagai fallback sampai koneksi tersedia lagi.
      debugPrint('[ApiService] MBS web session unavailable: $e');
    }
  }

  Future<void> _ensureMbsWebSession() async {
    final existing =
        _mbsSessionCookie ?? PreferenceService.getMbsSessionCookie();
    if (existing != null && existing.isNotEmpty) {
      _mbsSessionCookie = existing;
      return;
    }
    // Akun lama mungkin tidak mengaktifkan "ingat saya", tetapi kredensial
    // offline tetap disimpan setelah login pertama. Keduanya sah untuk
    // membentuk ulang sesi MBS tanpa meminta pengguna login kembali.
    // Halaman BBS memuat beberapa master secara paralel. Satu proses login
    // yang dipakai bersama mencegah request saling menimpa cookie ASP.NET.
    _mbsSessionRefresh ??= () async {
      final user =
          PreferenceService.getUser() ?? PreferenceService.getOfflineNik();
      final password = PreferenceService.getPassword() ??
          PreferenceService.getOfflinePassword();
      if (user != null &&
          user.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        await _loginMbsWeb(user, password);
      }
    }();
    try {
      await _mbsSessionRefresh;
    } finally {
      _mbsSessionRefresh = null;
    }
  }

  /// Sesi ini dipakai WebView untuk modul MBS yang kompleks agar tetap masuk
  /// dengan akun aplikasi tanpa meminta pengguna login kedua kali.
  Future<String?> getMbsWebSessionCookie() async {
    await _ensureMbsWebSession();
    return _mbsSessionCookie ?? PreferenceService.getMbsSessionCookie();
  }

  Future<void> _renewMbsWebSession() async {
    // Cookie ASP.NET dapat kedaluwarsa walaupun internet aktif. Kosongkan
    // salinan lama lalu bentuk sesi baru menggunakan kredensial login yang
    // tersimpan terenkripsi di perangkat.
    _mbsSessionCookie = null;
    await PreferenceService.setMbsSessionCookie('');
    await _ensureMbsWebSession();
  }

  bool _isMbsLoginPage(String html) {
    return html.contains('id="loginSplash"') ||
        html.contains("id='loginSplash'") ||
        html.contains('name="nrp"');
  }

  Future<Response<String>> _mbsGetWithSession(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    await _ensureMbsWebSession();
    var response =
        await _mbsDio().get<String>(path, queryParameters: queryParameters);
    if (_isMbsLoginPage(response.data ?? '')) {
      await _renewMbsWebSession();
      response =
          await _mbsDio().get<String>(path, queryParameters: queryParameters);
    }
    return response;
  }

  dynamic _decodeMbsJson(dynamic raw) {
    if (raw is String) {
      // globalAreasList pada halaman Razor ditulis sebagai literal JavaScript
      // (`{ id: 1, namaArea: ... }`), bukan JSON dengan key ber-quote.
      // Normalisasi hanya key sederhana sebelum didecode.
      final normalized = raw.replaceAllMapped(
        RegExp(r'([\{,]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:'),
        (match) => '${match.group(1)}"${match.group(2)}":',
      );
      return jsonDecode(normalized);
    }
    return raw;
  }

  List<Map<String, dynamic>> _webEntries(List<dynamic> values, String nameKey) {
    return values
        .whereType<Map>()
        .map((item) {
          final value = Map<String, dynamic>.from(item);
          return <String, dynamic>{
            // Daftar area dari web memakai `id`, sementara perusahaan memakai
            // `Id`. Keduanya adalah kontrak MBS yang sah.
            'id':
                int.tryParse((value['id'] ?? value['Id'])?.toString() ?? '') ??
                    0,
            'name': value[nameKey]?.toString() ?? '',
          };
        })
        .where((item) => item['id'] != 0 && item['name'] != '')
        .toList();
  }

  Future<Map<String, dynamic>?> _getMbsObservationOptions() async {
    await _ensureMbsWebSession();
    final cookie = _mbsSessionCookie ?? PreferenceService.getMbsSessionCookie();
    if (cookie == null || cookie.isEmpty) return null;
    try {
      final client = _mbsDio();
      final page = await client.get<String>('/Observation/Index');
      final html = page.data ?? '';
      if (page.statusCode != 200 || html.contains('id="loginSplash"')) {
        return null;
      }
      final areasJson =
          RegExp(r'var globalAreasList = (\[.*?\]);', dotAll: true)
              .firstMatch(html)
              ?.group(1);
      final companiesJson =
          RegExp(r'var globalCompaniesList = (\[.*?\]);', dotAll: true)
              .firstMatch(html)
              ?.group(1);
      final departmentsJson =
          RegExp(r'var globalCompanyDeptMap = (\{.*?\});', dotAll: true)
              .firstMatch(html)
              ?.group(1);
      if (areasJson == null ||
          companiesJson == null ||
          departmentsJson == null) {
        return null;
      }

      final areas = _webEntries(
          List<dynamic>.from(_decodeMbsJson(areasJson) as List), 'namaArea');
      final companies = _webEntries(
          List<dynamic>.from(_decodeMbsJson(companiesJson) as List), 'Nama');
      final departmentMap =
          Map<String, dynamic>.from(_decodeMbsJson(departmentsJson) as Map);
      final departmentNames = <String>{};
      for (final raw in departmentMap.values) {
        if (raw is List) {
          departmentNames.addAll(raw
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty));
        }
      }
      final departments = departmentNames.toList()..sort();
      final locations = <Map<String, dynamic>>[];
      final benchmarkResponses = await Future.wait(areas.map((area) async {
        try {
          final response = await client.get<String>('/Api/GetBenchmarks',
              queryParameters: {'areaUtama': area['name']});
          if (response.statusCode != 200) return const <Map<String, dynamic>>[];
          final items = _decodeMbsJson(response.data);
          if (items is! List) return const <Map<String, dynamic>>[];
          return items
              .whereType<Map>()
              .map((item) {
                final benchmark = Map<String, dynamic>.from(item);
                return <String, dynamic>{
                  'id': int.tryParse(benchmark['id']?.toString() ?? '') ?? 0,
                  'name': benchmark['namaBenchmark']?.toString() ?? '',
                  'area': area['name'],
                };
              })
              .where((item) => item['id'] != 0 && item['name'] != '')
              .toList();
        } catch (_) {
          return const <Map<String, dynamic>>[];
        }
      }));
      for (final rows in benchmarkResponses) {
        locations.addAll(rows);
      }

      const documents = [
        'Instruksi Kerja (IK)',
        'Job Safety Analysis (JSA)',
        'Prosedur Kerja (SOP)',
        'Lain-lain'
      ];
      const risks = [
        'Explosive',
        'Geotechnical',
        'Working at Height',
        'Isolation',
        'Lifting',
        'Traffic & Tyre',
        'Other'
      ];
      const levels = ['Rendah', 'Sedang', 'Tinggi', 'Ekstrim'];
      const subjects = [
        'Alat Pelindung Diri',
        'Peralatan',
        'Posisi Seseorang',
        'Prosedur Kerja',
        'Reaksi Seseorang'
      ];
      const results = ['Positive', 'Improvement', 'Violation'];
      List<Map<String, dynamic>> fixed(List<String> names) => List.generate(
          names.length, (index) => {'id': index + 1, 'name': names[index]});
      return {
        'areas': areas,
        'locations': locations,
        'companies': companies,
        'departments': fixed(departments),
        'documents': fixed(documents),
        'criticalRisks': fixed(risks),
        'riskLevels': fixed(levels),
        'subjects': fixed(subjects),
        'results': fixed(results),
      };
    } catch (e) {
      debugPrint('[ApiService] MBS Observation master unavailable: $e');
      return null;
    }
  }

  /// Options for Observasi are served from the shared MBS database, not from
  /// the app's legacy sample master tables.
  Future<Map<String, dynamic>?> getObservationOptions(
      {int? perusahaanId}) async {
    final webData = await _getMbsObservationOptions();
    if (webData != null) {
      await PreferenceService.setObservationOptionsCache(webData);
      return webData;
    }
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }
      final res = await dio.get('/observation/options', queryParameters: {
        if (perusahaanId != null && perusahaanId > 0)
          'perusahaanId': perusahaanId,
      });
      if (res.data is Map) {
        final data = Map<String, dynamic>.from(res.data as Map);
        await PreferenceService.setObservationOptionsCache(data);
        return data;
      }
    } catch (e) {
      debugPrint('[ApiService] Error fetching observation options: $e');
    }
    return null;
  }

  Future<bool> _deleteObservationOnMbsWeb(int id) async {
    await _ensureMbsWebSession();
    final cookie = _mbsSessionCookie ?? PreferenceService.getMbsSessionCookie();
    if (cookie == null || cookie.isEmpty) return false;
    try {
      final client = _mbsDio();
      // Laporan bisa sudah terhapus melalui web MBS atau percobaan sebelumnya,
      // sementara cache SQLite HP belum sempat dibersihkan. Dalam kondisi itu
      // tujuan pengguna (menghapus laporan) sudah tercapai; izinkan caller
      // membersihkan salinan lokalnya juga.
      final existing = await client.get<String>('/Observation/GetData/$id');
      if (existing.statusCode == 404) return true;
      if (existing.statusCode != 200) return false;

      // ASP.NET Core MVC memvalidasi anti-forgery token untuk operasi hapus.
      final formPage = await client.get<String>('/Observation/Index');
      final csrf = _csrfToken(formPage.data ?? '');
      if (formPage.statusCode != 200 || csrf.isEmpty) return false;

      final response = await client.post<String>('/Observation/Delete/$id',
          options: Options(headers: {
            'Cookie': cookie,
            Headers.contentTypeHeader: Headers.formUrlEncodedContentType,
          }),
          data: {'__RequestVerificationToken': csrf});
      // Endpoint web me-redirect kembali ke daftar Observasi jika berhasil.
      return response.statusCode == 302 || response.statusCode == 303;
    } catch (e) {
      debugPrint('[ApiService] MBS Observation delete failed: $e');
      return false;
    }
  }

  Future<bool> deleteObservation(int id) async {
    final deletedOnMbs = await _deleteObservationOnMbsWeb(id);
    if (deletedOnMbs) return true;
    try {
      _restoreStoredToken();
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      final res = await dio.delete('/tran/observation/$id');
      return res.data is Map && res.data['status'] == true;
    } catch (e) {
      debugPrint('[ApiService] Error deleting observation: $e');
      return false;
    }
  }

  Future<bool> updateObservation(int id, Map<String, dynamic> fields) async {
    final updatedOnMbs = await _updateObservationOnMbsWeb(id, fields);
    if (updatedOnMbs) return true;
    try {
      _restoreStoredToken();
      if (getToken.isEmpty) {
        debugPrint('[ApiService] Observation update blocked: no saved token.');
        return false;
      }
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      final fallbackFields = Map<String, dynamic>.from(fields);
      final image = fallbackFields['image'];
      if (image is MultipartFile) fallbackFields['image'] = image.clone();
      final res = await dio.put('/tran/observation/$id',
          data: FormData.fromMap(fallbackFields));
      return res.data is Map && res.data['status'] == true;
    } catch (e) {
      debugPrint('[ApiService] Error updating observation: $e');
      return false;
    }
  }

  Future<bool> _updateObservationOnMbsWeb(int id, Map<String, dynamic> fields,
      {bool resolveMissingId = true}) async {
    await _ensureMbsWebSession();
    for (var attempt = 0; attempt < 2; attempt++) {
      final cookie =
          _mbsSessionCookie ?? PreferenceService.getMbsSessionCookie();
      if (cookie == null || cookie.isEmpty) return false;
      try {
        final client = _mbsDio();
        final formPage = await client.get<String>('/Observation/Index');
        final csrf = _csrfToken(formPage.data ?? '');
        final formHtml = formPage.data ?? '';
        if (formPage.statusCode != 200 ||
            csrf.isEmpty ||
            _isMbsLoginPage(formHtml)) {
          if (attempt == 0) {
            await _renewMbsWebSession();
            continue;
          }
          return false;
        }

        String value(String key) => fields[key]?.toString() ?? '';
        String result(String raw) {
          switch (raw.trim().toUpperCase()) {
            case 'P':
              return 'Positive';
            case 'I':
              return 'Improvement';
            case 'V':
              return 'Violation';
            default:
              return raw;
          }
        }

        final body = <String, dynamic>{
          'id': id.toString(),
          'tanggal': value('tanggal'),
          'waktuStr': value('waktu').isNotEmpty ? value('waktu') : '12:00',
          'Area': value('area'),
          'Lokasi': value('lokasi'),
          'DetilLokasi': value('detil_lokasi'),
          'KegiatanYangDiamati': value('kegiatan_yang_diamati'),
          'PerusahaanId': value('perusahaan_id'),
          'PerusahaanYangDiamati': value('perusahaan_yang_diamati'),
          'DepartemenYangDiamati': value('departemen_yang_diamati'),
          'DokumenPendukung': value('dokumen_pendukung'),
          'ResikoKritis': value('resiko_kritis'),
          'TingkatResiko': value('tingkat_resiko'),
          'PerihalYangDiamati': value('perihal_yang_diamati'),
          'hasilObservasiList': result(value('hasil_observasi')),
          'keteranganList': value('keterangan'),
          'HasilObservasi': result(value('hasil_observasi')),
          'Keterangan': value('keterangan'),
          '__RequestVerificationToken': csrf,
        };
        final image = fields['image'];
        // MultipartFile hanya dapat dikirim satu kali. Gunakan clone sehingga
        // percobaan ulang (setelah sesi/ID dipulihkan) selalu mendapat stream
        // file yang baru.
        if (image is MultipartFile) body['fotoList'] = image.clone();
        final response = await client.post<String>('/Observation/Create',
            options: Options(headers: {'Cookie': cookie}),
            data: FormData.fromMap(body));
        // Aksi MVC biasanya redirect ke daftar (302), namun beberapa versi
        // server mengembalikan halaman sukses langsung (200). Halaman validasi
        // tetap berisi form dan ringkasan error, sehingga jangan anggap itu
        // sebagai penyimpanan yang berhasil.
        if (response.statusCode == 302 || response.statusCode == 303) {
          final location = response.headers.value('location') ?? '';
          if (!location.contains('/Observation') && attempt == 0) {
            await _renewMbsWebSession();
            continue;
          }
          return location.contains('/Observation');
        }
        final responseText = response.data?.toLowerCase() ?? '';
        final succeeded = response.statusCode == 200 &&
            !responseText.contains("validation-summary-errors") &&
            !responseText.contains("gagal memperbarui") &&
            !responseText.contains("gagal menyimpan");
        if (succeeded) return true;
        if (response.statusCode == 404 && resolveMissingId) {
          final resolvedId = await _findMbsObservationId(fields);
          if (resolvedId != null && resolvedId != id) {
            debugPrint(
                '[ApiService] Recovered stale MBS observation ID $id -> $resolvedId');
            return _updateObservationOnMbsWeb(resolvedId, fields,
                resolveMissingId: false);
          }
        }
        if (attempt == 0 && _isMbsLoginPage(response.data ?? '')) {
          await _renewMbsWebSession();
          continue;
        }
        debugPrint(
            '[ApiService] MBS Observation update rejected: ${response.statusCode}');
        return false;
      } catch (e) {
        if (attempt == 0) {
          await _renewMbsWebSession();
          continue;
        }
        debugPrint('[ApiService] MBS Observation update failed: $e');
        return false;
      }
    }
    return false;
  }

  String _matchMbsText(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  /// Versi lama aplikasi sempat menyimpan ID REST yang sudah tidak ada di
  /// halaman MBS. Cari satu laporan yang cocok dari histori MBS agar edit
  /// pengguna tetap menuju baris laporan yang sebenarnya.
  Future<int?> _findMbsObservationId(Map<String, dynamic> fields) async {
    final cookie = _mbsSessionCookie ?? PreferenceService.getMbsSessionCookie();
    if (cookie == null || cookie.isEmpty) return null;
    try {
      final page = await _mbsDio().get<String>('/Observation/Index');
      if (page.statusCode != 200 || _isMbsLoginPage(page.data ?? '')) {
        return null;
      }
      final targetPoint =
          _matchMbsText(fields['perihal_yang_diamati']?.toString() ?? '');
      final targetRemark =
          _matchMbsText(fields['keterangan']?.toString() ?? '');
      if (targetPoint.isEmpty || targetRemark.isEmpty) return null;

      final cards = RegExp(
        r'editObservation\((\d+)\)[\s\S]*?<strong>Perihal:</strong>\s*([^<]+)[\s\S]*?<p[^>]*>\s*([^<]+?)\s*</p>',
        caseSensitive: false,
      ).allMatches(page.data ?? '');
      for (final card in cards) {
        final point = _matchMbsText(card.group(2) ?? '');
        final remark = _matchMbsText(card.group(3) ?? '');
        if (point == targetPoint && remark == targetRemark) {
          return int.tryParse(card.group(1) ?? '');
        }
      }
    } catch (e) {
      debugPrint('[ApiService] MBS ID recovery failed: $e');
    }
    return null;
  }

  void _restoreStoredToken() {
    if (_token != null &&
        _token!.isNotEmpty &&
        !_token!.startsWith('offline_token_')) {
      return;
    }
    final saved =
        PreferenceService.getAuth()?.token ?? PreferenceService.getBgToken();
    if (saved != null &&
        saved.isNotEmpty &&
        !saved.startsWith('offline_token_')) {
      _token = saved;
    }
  }

  Future<List<String>> getBenchmarks(String areaUtama,
      {int? perusahaanId}) async {
    try {
      _restoreStoredToken();
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $_token';
      }
      final res = await dio.get('/master/benchmarks', queryParameters: {
        'areaUtama': areaUtama,
        if (perusahaanId != null && perusahaanId > 0)
          'perusahaanId': perusahaanId,
      });
      if (res.data is List) {
        final list = (res.data as List)
            .map((e) =>
                (e is Map ? e['namaBenchmark']?.toString() : e.toString()) ??
                '')
            .where((s) => s.isNotEmpty)
            .toList();
        return list;
      }
    } catch (e) {
      debugPrint('[ApiService] Error fetching benchmarks for $areaUtama: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> createBenchmark({
    required String areaUtama,
    required String namaBenchmark,
    int? perusahaanId,
    String? createdByNik,
    String? createdByName,
  }) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }
      final res = await dio.post('/master/benchmarks', data: {
        'areaUtama': areaUtama,
        'namaBenchmark': namaBenchmark,
        if (perusahaanId != null && perusahaanId > 0)
          'perusahaanId': perusahaanId,
        'createdByNik': createdByNik,
        'createdByName': createdByName,
      });
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (e) {
      debugPrint('[ApiService] Error creating benchmark: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> createArea({
    required String namaArea,
    String? createdByNik,
    String? createdByName,
  }) async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $getToken';
      }
      final res = await dio.post('/master/areas', data: {
        'namaArea': namaArea,
        'createdByNik': createdByNik,
        'createdByName': createdByName,
      });
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (e) {
      debugPrint('[ApiService] Error creating area: $e');
    }
    return null;
  }

  /// Membaca master dan riwayat Safety Talk langsung dari MBS SAP.  Modul ini
  /// memang dikelola oleh aplikasi web MBS, sehingga master lokal lama tidak
  /// boleh dijadikan sumber utama.
  Future<Map<String, dynamic>?> getSafetyTalkData() async {
    await _ensureMbsWebSession();
    try {
      final page = await _mbsDio().get<String>('/SafetyTalk/Index');
      final html = page.data ?? '';
      if (page.statusCode != 200 || _isMbsLoginPage(html)) return null;
      final rawAreas = RegExp(r'var globalAreasList = (\[.*?\]);', dotAll: true)
          .firstMatch(html)
          ?.group(1);
      if (rawAreas == null) return null;
      final areas = _webEntries(
        List<dynamic>.from(_decodeMbsJson(rawAreas) as List),
        'namaArea',
      );
      final talks = <Map<String, dynamic>>[];
      final cards = RegExp(
        r'<span[^>]*font-weight: 700; font-size: 14px[^>]*>\s*([^<]+?)\s*</span>[\s\S]*?bi-geo-alt-fill[^>]*></i>\s*([^<]+?)(?:\s*</span>)[\s\S]*?onclick="editSafetyTalk\((\d+)\)"',
        caseSensitive: false,
      ).allMatches(html);
      for (final card in cards) {
        talks.add({
          'id': int.tryParse(card.group(3) ?? '') ?? 0,
          'judul': card.group(1)?.trim() ?? '',
          'areaLokasi': card.group(2)?.trim() ?? '',
        });
      }
      return {'areas': areas, 'talks': talks};
    } catch (e) {
      debugPrint('[ApiService] MBS Safety Talk unavailable: $e');
      return null;
    }
  }

  Future<List<String>> getSafetyTalkBenchmarks(String area) async {
    if (area.trim().isEmpty) return const [];
    try {
      final res = await _mbsGetWithSession('/Api/GetBenchmarks',
          queryParameters: {'areaUtama': area});
      final decoded = _decodeMbsJson(res.data);
      if (res.statusCode != 200 || decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => item['namaBenchmark']?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[ApiService] Safety Talk benchmark unavailable: $e');
      return const [];
    }
  }

  /// Master Coaching harus mengikuti halaman MBS, bukan bergantung pada
  /// salinan SQLite yang mungkin belum pernah tersinkron pada perangkat baru.
  Future<Map<String, dynamic>?> getCoachingOptions() async {
    try {
      // Area dan perusahaan di MBS adalah master bersama. Halaman Observasi
      // selalu menyertakan dua daftar lengkap ini, sedangkan beberapa versi
      // halaman Coaching hanya merendernya setelah JavaScript berjalan.
      final masterPage = await _mbsGetWithSession('/Observation/Index');
      final html = masterPage.data ?? '';
      if (masterPage.statusCode != 200 || _isMbsLoginPage(html)) return null;

      List<Map<String, dynamic>> readVariable(
        String source,
        List<String> names, {
        required String label,
      }) {
        for (final name in names) {
          final raw = RegExp('var\\s+$name\\s*=\\s*(\\[.*?\\]);',
                  dotAll: true, caseSensitive: false)
              .firstMatch(source)
              ?.group(1);
          if (raw == null) continue;
          try {
            final decoded = _decodeMbsJson(raw);
            if (decoded is List) {
              return _webEntries(List<dynamic>.from(decoded), label);
            }
          } catch (_) {}
        }
        return const [];
      }

      final areas =
          readVariable(html, ['globalAreasList'], label: 'namaArea');
      final companies =
          readVariable(html, ['globalCompaniesList'], label: 'Nama');
      final coachingPage = await _mbsGetWithSession('/Coaching/Index');
      final coachingHtml = coachingPage.data ?? '';
      var themes = readVariable(
        coachingHtml,
        ['globalCoachingThemes', 'coachingThemes', 'temaCoachingList'],
        label: 'name',
      );

      // Beberapa versi MBS menulis tema langsung sebagai <option>, bukan
      // variabel JavaScript. Ambil hanya select bertema coaching.
      if (themes.isEmpty) {
        final select = RegExp(
          r'<select[^>]*(?:tema|theme)[^>]*>([\s\S]*?)</select>',
          caseSensitive: false,
        ).firstMatch(coachingHtml)?.group(1);
        if (select != null) {
          final values = <Map<String, dynamic>>[];
          for (final option in RegExp(
                  r'''<option[^>]*value=["']?([^"' >]+)[^>]*>([\s\S]*?)</option>''',
                  caseSensitive: false)
              .allMatches(select)) {
            final id = int.tryParse(option.group(1) ?? '') ?? 0;
            final name =
                option.group(2)?.replaceAll(RegExp(r'<[^>]+>'), '').trim();
            if (id > 0 && name != null && name.isNotEmpty) {
              values.add({'id': id, 'name': name});
            }
          }
          themes = values;
        }
      }
      // Tema standar juga dipakai sebagai fallback offline oleh web lama.
      if (themes.isEmpty) {
        themes = const [
          {'id': 1, 'name': 'Sosialisasi'},
          {'id': 2, 'name': 'Sharing Knowledge'},
          {'id': 3, 'name': 'Pembinaan'},
        ];
      }
      if (areas.isEmpty && companies.isEmpty) return null;
      return {'areas': areas, 'companies': companies, 'themes': themes};
    } catch (e) {
      debugPrint('[ApiService] MBS Coaching master unavailable: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getCoachingBenchmarks(String area) async {
    if (area.trim().isEmpty) return const [];
    try {
      final response = await _mbsGetWithSession('/Api/GetBenchmarks',
          queryParameters: {'areaUtama': area.trim()});
      final decoded = _decodeMbsJson(response.data);
      if (response.statusCode != 200 || decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((raw) {
            final item = Map<String, dynamic>.from(raw);
            return <String, dynamic>{
              'id': int.tryParse(item['id']?.toString() ?? '') ?? 0,
              'name': item['namaBenchmark']?.toString().trim() ?? '',
            };
          })
          .where((item) => item['id'] != 0 && item['name']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[ApiService] MBS Coaching benchmark unavailable: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> searchCoachingEmployees(
      String query) async {
    if (query.trim().length < 2) return const [];
    try {
      final response = await _mbsGetWithSession('/Api/SearchEmployee',
          queryParameters: {'query': query.trim(), 'lintasPerusahaan': true});
      final decoded = _decodeMbsJson(response.data);
      if (response.statusCode != 200 || decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((raw) {
            final item = Map<String, dynamic>.from(raw);
            return <String, dynamic>{
              'id': item['id'] ?? item['Id'] ?? item['nik'],
              'no_nik':
                  item['nik']?.toString() ?? item['noNik']?.toString() ?? '',
              'nama_lengkap':
                  item['nama']?.toString() ?? item['name']?.toString() ?? '',
              'posisi': item['jabatan']?.toString() ?? '',
              'departemen': item['departemen']?.toString() ?? '',
              'perusahaan': item['perusahaan']?.toString() ?? '',
            };
          })
          .where((item) => item['nama_lengkap']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[ApiService] MBS Coaching participant unavailable: $e');
      return null;
    }
  }

  /// Persis alur halaman BBS web: Detail Lokasi hanya berasal dari
  /// `/Api/GetBenchmarks?areaUtama=...`. Nilai `null` berarti permintaan
  /// gagal; daftar kosong berarti MBS memang belum mempunyai benchmark untuk
  /// area tersebut. Keduanya sengaja dibedakan agar UI tidak menyamarkan
  /// kegagalan koneksi sebagai master kosong.
  Future<List<String>?> getBbsBenchmarks(String area) async {
    if (area.trim().isEmpty) return const [];
    try {
      final response = await _mbsGetWithSession(
        '/Api/GetBenchmarks',
        queryParameters: {'areaUtama': area.trim()},
      );
      final decoded = _decodeMbsJson(response.data);
      if (response.statusCode != 200 || decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((item) => item['namaBenchmark']?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    } catch (e) {
      debugPrint('[ApiService] BBS benchmark unavailable: $e');
      return null;
    }
  }

  /// Endpoint master yang sama dipakai halaman web BBS. Benchmark baru harus
  /// disimpan ke MBS, bukan hanya ditambahkan sementara di perangkat.
  Future<String?> createBbsBenchmark({
    required String areaUtama,
    required String namaBenchmark,
  }) async {
    await _ensureMbsWebSession();
    final area = areaUtama.trim();
    final name = namaBenchmark.trim();
    if (area.isEmpty || name.isEmpty) return null;
    try {
      final response = await _mbsDio().post<String>(
        '/Api/AddBenchmark',
        data: {
          'areaUtama': area,
          'namaBenchmark': name,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'X-Requested-With': 'XMLHttpRequest'},
        ),
      );
      final decoded = _decodeMbsJson(response.data);
      if (response.statusCode != 200 && response.statusCode != 201) return null;
      if (decoded is Map) {
        final data = decoded['data'];
        if (data is Map && data['namaBenchmark'] != null) {
          return data['namaBenchmark'].toString();
        }
      }
      return name;
    } catch (e) {
      debugPrint('[ApiService] BBS benchmark create failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSafetyTalk(int id) async {
    await _ensureMbsWebSession();
    try {
      final res = await _mbsDio().get<String>('/SafetyTalk/GetData/$id');
      if (res.statusCode != 200 || res.data == null) return null;
      final decoded = _decodeMbsJson(res.data);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (e) {
      debugPrint('[ApiService] Safety Talk detail unavailable: $e');
      return null;
    }
  }

  Future<bool> submitSafetyTalk(Map<String, dynamic> data) async {
    await _ensureMbsWebSession();
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final client = _mbsDio();
        final page = await client.get<String>('/SafetyTalk/Index');
        final html = page.data ?? '';
        final csrf = _csrfToken(html);
        if (page.statusCode != 200 || csrf.isEmpty || _isMbsLoginPage(html)) {
          if (attempt == 0) {
            await _renewMbsWebSession();
            continue;
          }
          return false;
        }
        final body = <String, dynamic>{
          'id': data['id']?.toString() ?? '',
          'tanggal': data['tanggal'],
          'waktuStr': data['waktuStr'],
          'area': data['area'],
          'detilLokasi': data['detilLokasi'],
          'lokasi': data['lokasi'],
          'judul': data['judul'],
          'keterangan': data['keterangan'],
          '__RequestVerificationToken': csrf,
        };
        final selfPath = data['fotoDiri']?.toString();
        final eventPath = data['fotoKegiatan']?.toString();
        if (selfPath != null && selfPath.isNotEmpty) {
          body['fotoDiri'] = await MultipartFile.fromFile(selfPath);
        }
        if (eventPath != null && eventPath.isNotEmpty) {
          body['fotoKegiatan'] = await MultipartFile.fromFile(eventPath);
        }
        final res = await client.post<String>('/SafetyTalk/Submit',
            data: FormData.fromMap(body),
            options: Options(headers: {'X-Requested-With': 'XMLHttpRequest'}));
        if (res.statusCode == 200 || res.statusCode == 201) return true;
        if (attempt == 0 && _isMbsLoginPage(res.data ?? '')) {
          await _renewMbsWebSession();
          continue;
        }
        return false;
      } catch (e) {
        debugPrint('[ApiService] Safety Talk submit failed: $e');
        if (attempt == 0) {
          await _renewMbsWebSession();
          continue;
        }
      }
    }
    return false;
  }

  Future<bool> deleteSafetyTalk(int id) async {
    await _ensureMbsWebSession();
    try {
      final client = _mbsDio();
      final page = await client.get<String>('/SafetyTalk/Index');
      final csrf = _csrfToken(page.data ?? '');
      if (csrf.isEmpty) return false;
      final res = await client.post<String>('/SafetyTalk/Delete/$id',
          data: {
            '__RequestVerificationToken': csrf,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType));
      return res.statusCode == 200 ||
          res.statusCode == 302 ||
          res.statusCode == 303;
    } catch (e) {
      debugPrint('[ApiService] Safety Talk delete failed: $e');
      return false;
    }
  }

  /// Master BBS wajib berasal dari MBS agar kategori dan butir perilaku di
  /// mobile selalu sama dengan halaman web.
  Future<List<Map<String, dynamic>>> getBbsCategories(String type) async {
    try {
      final res = await _mbsGetWithSession('/Bbs/GetCategories',
          queryParameters: {'type': type});
      final raw = _decodeMbsJson(res.data);
      return raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [];
    } catch (e) {
      debugPrint('[ApiService] BBS category unavailable: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getBbsCompanies() async {
    try {
      final page = await _mbsGetWithSession('/Bbs/Index');
      final raw = RegExp(r'var globalCompaniesList = (\[.*?\]);', dotAll: true)
          .firstMatch(page.data ?? '')
          ?.group(1);
      if (raw == null) return const [];
      final decoded = _decodeMbsJson(raw);
      return decoded is List
          ? decoded
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
          : const [];
    } catch (e) {
      debugPrint('[ApiService] BBS company unavailable: $e');
      return const [];
    }
  }

  Future<List<String>> getBbsAreas() async {
    try {
      final page = await _mbsGetWithSession('/Bbs/Index');
      final html = page.data ?? '';
      final serverRaw = RegExp(r'var serverAreas = (\[.*?\]);', dotAll: true)
          .firstMatch(html)
          ?.group(1);
      final standardRaw =
          RegExp(r'var defaultStandardAreas = (\[.*?\]);', dotAll: true)
              .firstMatch(html)
              ?.group(1);
      final names = <String>{};
      for (final raw in [serverRaw, standardRaw]) {
        final decoded = raw == null ? null : _decodeMbsJson(raw);
        if (decoded is List) {
          for (final row in decoded) {
            final name = row is Map
                ? (row['namaArea'] ??
                        row['NamaArea'] ??
                        row['name'] ??
                        row['Name'])
                    ?.toString()
                    .trim()
                : row?.toString().trim();
            if (name != null && name.isNotEmpty) {
              names.add(name);
            }
          }
        }
      }
      return names.toList()..sort();
    } catch (e) {
      debugPrint('[ApiService] BBS area unavailable: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getBbsTopics(int categoryId) async {
    try {
      final res = await _mbsGetWithSession('/Bbs/GetTopics',
          queryParameters: {'categoryId': categoryId});
      final raw = _decodeMbsJson(res.data);
      return raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const [];
    } catch (e) {
      debugPrint('[ApiService] BBS topic unavailable: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getBbsBehaviors(int categoryId,
      {int? topicId}) async {
    try {
      final res = await _mbsGetWithSession('/Bbs/GetBehaviors',
          queryParameters: {
            'categoryId': categoryId,
            if (topicId != null) 'topicId': topicId
          });
      final raw = _decodeMbsJson(res.data);
      return raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [];
    } catch (e) {
      debugPrint('[ApiService] BBS behavior unavailable: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> searchBbsWorkers(String query,
      {int? companyId}) async {
    if (query.trim().length < 2) return const [];
    try {
      final res =
          await _mbsGetWithSession('/Bbs/SearchWorker', queryParameters: {
        'q': query.trim(),
        if (companyId != null) 'companyId': companyId,
      });
      final raw = _decodeMbsJson(res.data);
      return raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const [];
    } catch (e) {
      debugPrint('[ApiService] BBS worker search unavailable: $e');
      return const [];
    }
  }

  Future<bool> submitBbs(Map<String, dynamic> values,
      {String? photoPath}) async {
    await _ensureMbsWebSession();
    try {
      final client = _mbsDio();
      final page = await client.get<String>('/Bbs/Index');
      final csrf = _csrfToken(page.data ?? '');
      if (csrf.isEmpty || _isMbsLoginPage(page.data ?? '')) return false;
      final data = <String, dynamic>{
        ...values,
        '__RequestVerificationToken': csrf
      };
      final form = FormData();
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is Iterable) {
          for (final item in value) {
            form.fields.add(MapEntry(entry.key, item.toString()));
          }
        } else {
          form.fields.add(MapEntry(entry.key, value.toString()));
        }
      }
      if (photoPath != null && photoPath.isNotEmpty) {
        form.files
            .add(MapEntry('foto', await MultipartFile.fromFile(photoPath)));
      }
      final result = await client.post<String>('/Bbs/Create', data: form);
      return result.statusCode == 200 ||
          result.statusCode == 302 ||
          result.statusCode == 303;
    } catch (e) {
      debugPrint('[ApiService] BBS submit failed: $e');
      return false;
    }
  }

  dynamic errorHandler(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return <String, dynamic>{
        'message': 'Koneksi ke server timeout',
        'isOffline': true,
      };
    }

    if (err.type == DioExceptionType.connectionError) {
      return <String, dynamic>{
        'message': 'Tidak dapat terhubung ke server (Connection error)',
        'isOffline': true,
      };
    }

    if (err.type == DioExceptionType.badResponse) {
      final statusCode = err.response?.statusCode;
      if (statusCode != null && statusCode >= 502 && statusCode <= 504) {
        return <String, dynamic>{
          'message': 'Server tidak dapat dijangkau ($statusCode)',
          'isOffline': true,
        };
      }
      try {
        var res =
            Map<String, dynamic>.from(jsonDecode(err.response.toString()));
        if ((res['message'] ?? '') != '') {
          return <String, dynamic>{'message': res['message']};
        }
        if ((res['detail'] ?? '') != '') {
          return <String, dynamic>{'message': res['detail']};
        }
        if ((res['password'] ?? '') != '' &&
            (res['password'] as List).isNotEmpty) {
          return <String, dynamic>{'message': res['password'][0]};
        }
      } catch (_) {}
    }

    if (err.response == null) {
      final msg = err.message?.toString() ?? 'Koneksi ke server terputus';
      return <String, dynamic>{
        'message': msg,
        'isOffline': true,
      };
    }

    try {
      return Map<String, dynamic>.from(jsonDecode(err.response.toString()));
    } catch (_) {
      return <String, dynamic>{
        'message': err.message?.toString() ?? 'Terjadi kesalahan sistem'
      };
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> getSapQualityDashboard({
    String? nik,
    int? year,
    int? month,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (nik != null && nik.isNotEmpty) query['nik'] = nik;
      if (year != null) query['year'] = year;
      if (month != null) query['month'] = month;

      final res = await dio.get('/performance/sap-quality-dashboard', queryParameters: query);
      if (res.statusCode == 200 && res.data != null) {
        return Right(Map<String, dynamic>.from(res.data));
      }
      return Left({'message': 'Gagal mengambil data kualitas SAP.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  // ==================== DPA (Driver Performance Assessment) ====================
  Future<Response> _dpaRequest(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final List<String> targets = [
      'http://127.0.0.1:5200/api$cleanPath',
      'http://192.168.130.236:5200/api$cleanPath',
      'http://192.168.137.1:5200/api$cleanPath',
      '$baseUrl/api$cleanPath',
      '$baseUrl$cleanPath',
    ];

    DioException? lastDioError;
    Exception? lastException;

    for (final targetUrl in targets) {
      try {
        final client = Dio(BaseOptions(
          headers: {
            'Accept': 'application/json',
            'Connection': 'Keep-Alive',
            'company': company,
            if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
          },
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 8),
        ));

        final res = await client.request(
          targetUrl,
          data: data,
          queryParameters: queryParameters,
          options: Options(method: method),
        );

        if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
          return res;
        }
      } on DioException catch (e) {
        lastDioError = e;
        if (e.response?.statusCode == 404 ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.unknown) {
          continue;
        }
        rethrow;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }

    if (lastDioError != null) throw lastDioError;
    throw lastException ?? Exception('Gagal menghubungi server DPA');
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> getDpaList({
    String? nik,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (nik != null && nik.isNotEmpty) query['nik'] = nik;
      if (search != null && search.isNotEmpty) query['search'] = search;

      final res = await _dpaRequest('/dpa', queryParameters: query);
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Gagal mengambil data penilaian driver.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> getDpaDetail(int id) async {
    try {
      final res = await _dpaRequest('/dpa/$id');
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Gagal mengambil detail penilaian driver.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, List<dynamic>>> searchDpaDriver(String query) async {
    try {
      final res = await _dpaRequest('/dpa/search-driver', queryParameters: {'query': query});
      if (res.data is List) {
        return Right(List<dynamic>.from(res.data as List));
      }
      return const Right([]);
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> addDpaDriver(String driverNama, {String? createdByNik}) async {
    try {
      final res = await _dpaRequest('/dpa/add-driver', method: 'POST', data: {
        'driverNama': driverNama,
        'createdByNik': createdByNik,
      });
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Gagal menambahkan driver.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> saveDpaReport(Map<String, dynamic> data) async {
    try {
      final res = await _dpaRequest('/dpa', method: 'POST', data: data);
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Gagal menyimpan penilaian driver.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> deleteDpaReport(int id) async {
    try {
      final res = await _dpaRequest('/dpa/$id', method: 'DELETE');
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  // ==================== FCI (Front Condition Index) ====================
  Future<Response> _fciRequest(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final List<String> targets = [
      'http://127.0.0.1:5200/api$cleanPath',
      'http://192.168.130.236:5200/api$cleanPath',
      'http://192.168.137.1:5200/api$cleanPath',
      '$baseUrl/api$cleanPath',
      '$baseUrl$cleanPath',
    ];

    DioException? lastDioError;
    Exception? lastException;

    for (final targetUrl in targets) {
      try {
        final client = Dio(BaseOptions(
          headers: {
            'Accept': 'application/json',
            'Connection': 'Keep-Alive',
            'company': company,
            if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
          },
          contentType: data is FormData ? 'multipart/form-data' : Headers.jsonContentType,
          responseType: ResponseType.json,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 10),
        ));

        final res = await client.request(
          targetUrl,
          data: data,
          queryParameters: queryParameters,
          options: Options(method: method),
        );

        if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
          return res;
        }
      } on DioException catch (e) {
        lastDioError = e;
        if (e.response?.statusCode == 404 ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.unknown) {
          continue;
        }
        rethrow;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }

    if (lastDioError != null) throw lastDioError;
    throw lastException ?? Exception('Gagal menghubungi server FCI');
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> getFciList({
    String? userNik,
    String? userNama,
    int? companyId,
    String? companyName,
    String? scope,
    String? search,
    String? pit,
    String? kategori,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (userNik != null && userNik.isNotEmpty) query['userNik'] = userNik;
      if (userNama != null && userNama.isNotEmpty) query['userNama'] = userNama;
      if (companyId != null && companyId > 0) query['companyId'] = companyId;
      if (companyName != null && companyName.isNotEmpty) query['companyName'] = companyName;
      if (scope != null && scope.isNotEmpty) query['scope'] = scope;
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (pit != null && pit.isNotEmpty) query['pit'] = pit;
      if (kategori != null && kategori.isNotEmpty) query['kategori'] = kategori;
      if (startDate != null) query['startDate'] = startDate.toIso8601String();
      if (endDate != null) query['endDate'] = endDate.toIso8601String();

      final res = await _fciRequest('/fci', queryParameters: query);
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Gagal mengambil data laporan FCI.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> getFciDetail(int id) async {
    try {
      final res = await _fciRequest('/fci/$id');
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Gagal mengambil detail laporan FCI.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> saveFciReport(FormData data) async {
    try {
      final res = await _fciRequest('/fci', method: 'POST', data: data);
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Gagal menyimpan laporan FCI.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> deleteFciReport(int id) async {
    try {
      final res = await _fciRequest('/fci/$id', method: 'DELETE');
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  // ==================== RCI (Road Condition Index) ====================
  Future<Response> _rciRequest(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final List<String> targets = [
      'http://127.0.0.1:5200/api$cleanPath',
      'http://192.168.130.236:5200/api$cleanPath',
      'http://192.168.137.1:5200/api$cleanPath',
      '$baseUrl/api$cleanPath',
      '$baseUrl$cleanPath',
    ];

    DioException? lastDioError;
    Exception? lastException;

    for (final targetUrl in targets) {
      try {
        final client = Dio(BaseOptions(
          headers: {
            'Accept': 'application/json',
            'Connection': 'Keep-Alive',
            'company': company,
            if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
          },
          contentType: data is FormData ? 'multipart/form-data' : Headers.jsonContentType,
          responseType: ResponseType.json,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 10),
        ));

        final res = await client.request(
          targetUrl,
          data: data,
          queryParameters: queryParameters,
          options: Options(method: method),
        );

        if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
          return res;
        }
      } on DioException catch (e) {
        lastDioError = e;
        if (e.response?.statusCode == 404 ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.unknown) {
          continue;
        }
        rethrow;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }

    if (lastDioError != null) throw lastDioError;
    throw lastException ?? Exception('Gagal menghubungi server RCI');
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> getRciList({
    String? userNik,
    String? userNama,
    int? companyId,
    String? companyName,
    String? scope,
    String? search,
    String? namaJalan,
    String? kategori,
    String? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (userNik != null && userNik.isNotEmpty) query['userNik'] = userNik;
      if (userNama != null && userNama.isNotEmpty) query['userNama'] = userNama;
      if (companyId != null && companyId > 0) query['companyId'] = companyId;
      if (companyName != null && companyName.isNotEmpty) query['companyName'] = companyName;
      if (scope != null && scope.isNotEmpty) query['scope'] = scope;
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (namaJalan != null && namaJalan.isNotEmpty) query['namaJalan'] = namaJalan;
      if (kategori != null && kategori.isNotEmpty) query['kategori'] = kategori;
      if (statusFilter != null && statusFilter.isNotEmpty) query['statusFilter'] = statusFilter;
      if (startDate != null) query['startDate'] = startDate.toIso8601String();
      if (endDate != null) query['endDate'] = endDate.toIso8601String();

      final res = await _rciRequest('/rci', queryParameters: query);
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Gagal mengambil data laporan RCI.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> getRciDetail(int id) async {
    try {
      final res = await _rciRequest('/rci/$id');
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Gagal mengambil detail laporan RCI.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> saveRciReport(FormData data) async {
    try {
      final res = await _rciRequest('/rci', method: 'POST', data: data);
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Gagal menyimpan laporan RCI.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> approveRciReport(
    int id, {
    required String nik,
    required String nama,
    required String role,
    String status = 'Approved',
    String? notes,
  }) async {
    try {
      final body = {
        'nik': nik,
        'nama': nama,
        'role': role,
        'status': status,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };
      final res = await _rciRequest('/rci/$id/approve', method: 'POST', data: body);
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Left({'message': 'Gagal menyetujui laporan RCI.'});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<Either<Map<String, dynamic>, Map<String, dynamic>>> deleteRciReport(int id) async {
    try {
      final res = await _rciRequest('/rci/$id', method: 'DELETE');
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (e) {
      return Left(errorHandler(e) as Map<String, dynamic>);
    } catch (e) {
      return Left({'message': e.toString()});
    }
  }

  Future<List<Map<String, dynamic>>> searchRciEmployees(String q) async {
    try {
      if (q.trim().length < 2) return [];
      final res = await _rciRequest('/rci/search-employees', queryParameters: {'q': q.trim()});
      if (res.data is Map && res.data['data'] is List) {
        final list = res.data['data'] as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}



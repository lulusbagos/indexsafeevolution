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

class ApiService {
  // Hotspot Tethering Laptop = http://192.168.137.1:5200
  // Wi-Fi Kantor / LAN = http://192.168.130.236:5200
  // USB ADB Reverse = http://127.0.0.1:5200
  // PROD = https://indexsafeevolution.indexim.id
  final baseUrl = 'http://127.0.0.1:5200';
  bool get isLocalDev => baseUrl.contains('192.168.') || baseUrl.contains('127.0.0.1');
  final company = 'IC';
  late Dio dio;

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: '$baseUrl/api',
        headers: {
          'Accept': 'application/json',
          'Connection': 'Keep-Alive',
          'company': company,
        },
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        receiveDataWhenStatusError: true,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    )..interceptors.add(LogInterceptor(
        request: false,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        logPrint: (o) => debugPrint(o.toString(), wrapWidth: 1024),
      ));
  }

  static String? _token;

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
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200'
              : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: '$fallbackHost/api',
            headers: dio.options.headers,
            contentType: Headers.jsonContentType,
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 5),
          ));
          res = await fallbackDio.post('/login',
              data: json.encode(loginPayload));
          dio.options.baseUrl = '$fallbackHost/api';
        } else {
          rethrow;
        }
      }

      var data = AuthModel.fromJson(Map<String, dynamic>.from(res.data as Map));
      _token = data.token;
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
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200'
              : baseUrl;
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

  Future<Either<Map, Map>> scanQr(String code, {String? scanType, double? lat, double? lng, double? acc}) async {
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
        final total = (m['total_pending_count'] as num?)?.toInt() ?? (unread + unactioned);
        return {
          'unread': unread,
          'unactioned': unactioned,
          'total': total,
        };
      }
      return {'unread': 0, 'unactioned': 0, 'total': 0};
    } catch (_) {
      try {
        var resFallback = await dio.get('/notifications', queryParameters: {'limit': 1});
        if (resFallback.data is Map) {
          final m = resFallback.data as Map;
          final unread = (m['unread_count'] as num?)?.toInt() ?? 0;
          final unactioned = (m['unactioned_count'] as num?)?.toInt() ?? 0;
          final total = (m['total_pending_count'] as num?)?.toInt() ?? (unread + unactioned);
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

  Future<Either<Map, List<NotificationItemModel>>> getNotifications({int limit = 30}) async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res = await dio.get('/notifications', queryParameters: {'limit': limit});
      if (res.data is Map && res.data['data'] is List) {
        final list = (res.data['data'] as List)
            .map((item) => NotificationItemModel.fromJson(Map<String, dynamic>.from(item as Map)))
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
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200'
              : baseUrl;
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
            .map((item) => IncidentNewsModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        return Right(list);
      }
      return const Right([]);
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, List<IncidentNewsModel>>> getHomeBanners({int limit = 5}) async {
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
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200'
              : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: '$fallbackHost/api',
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 6),
          ));
          res = await fallbackDio.get('/incidents/banners', queryParameters: params);
        } else {
          rethrow;
        }
      }

      if (res.data is Map && res.data['data'] is List) {
        final list = (res.data['data'] as List)
            .map((item) => IncidentNewsModel.fromJson(Map<String, dynamic>.from(item as Map)))
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
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200'
              : baseUrl;
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
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200'
              : baseUrl;
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
      return const Right({'success': true, 'message': 'Roster berhasil disimpan'});
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
      return const Right({'success': true, 'message': 'Roster berhasil dihapus'});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> getSafeMapPoints({int? month, int? year}) async {
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
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200'
              : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
          ));
          res = await fallbackDio.get('/api/performance/safemap', queryParameters: {
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
        res = await dio.post('/api/performance/safemap/close-hazard', data: formData);
      } on DioException catch (dioErr) {
        if (dioErr.type == DioExceptionType.connectionTimeout ||
            dioErr.type == DioExceptionType.connectionError ||
            dioErr.type == DioExceptionType.unknown ||
            dioErr.response?.statusCode == 404) {
          final fallbackHost = baseUrl.contains('192.168.')
              ? 'http://127.0.0.1:5200'
              : baseUrl;
          final fallbackDio = Dio(BaseOptions(
            baseUrl: fallbackHost,
            headers: dio.options.headers,
            connectTimeout: const Duration(seconds: 4),
          ));
          res = await fallbackDio.post('/api/performance/safemap/close-hazard', data: formData);
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
          res = await fallbackDio.post('/hazard/reassign', data: jsonEncode(payload));
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

  Future<Either<Map, List<Map<String, dynamic>>>> searchPja(String query, {bool lintasPerusahaan = true}) async {
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
          res = await fallbackDio.get('/hazard/search-pja', queryParameters: params);
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

  Future<Either<Map, Map<String, dynamic>>> takeUpHazard(int id, {String? note}) async {
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
          res = await fallbackDio.get('/performance/safemap', queryParameters: params);
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

  Future<Either<Map, Map<String, dynamic>>> recordPermitViolation(Map<String, dynamic> payload) async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false &&
          con.contains(ConnectivityResult.ethernet) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.post('/qr/permit/violation', data: json.encode(payload));
      if (res.data is Map) {
        return Right(Map<String, dynamic>.from(res.data as Map));
      }
      return const Right({});
    } on DioException catch (err) {
      return Left(errorHandler(err));
    }
  }

  Future<Either<Map, Map<String, dynamic>>> recordPermitMovement(Map<String, dynamic> payload) async {
    dio.options.headers['Authorization'] = 'Bearer $_token';
    try {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false &&
          con.contains(ConnectivityResult.ethernet) == false) {
        return const Left({'message': 'No internet access!'});
      }

      var res = await dio.post('/qr/permit/movement', data: json.encode(payload));
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
        if (perusahaanId != null && perusahaanId > 0) 'perusahaanId': perusahaanId,
      });
      if (res.data is List) {
        final list = (res.data as List)
            .map((e) => (e is Map ? e['namaArea']?.toString() : e.toString()) ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        return list;
      }
    } catch (e) {
      debugPrint('[ApiService] Error fetching master areas: $e');
    }
    return [];
  }

  Future<List<String>> getBenchmarks(String areaUtama, {int? perusahaanId}) async {
    try {
      final res = await dio.get('/master/benchmarks', queryParameters: {
        'areaUtama': areaUtama,
        if (perusahaanId != null && perusahaanId > 0) 'perusahaanId': perusahaanId,
      });
      if (res.data is List) {
        final list = (res.data as List)
            .map((e) => (e is Map ? e['namaBenchmark']?.toString() : e.toString()) ?? '')
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
        if (perusahaanId != null && perusahaanId > 0) 'perusahaanId': perusahaanId,
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
        var res = Map<String, dynamic>.from(jsonDecode(err.response.toString()));
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
}

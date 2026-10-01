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
  // LOCAL = http://127.0.0.1:5200 (USB adb reverse or local network)
  // LAN = http://192.168.0.6:5200
  // PROD = https://apiis.icapps.id
  final baseUrl = 'http://192.168.0.6:5200';
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
          final fallbackHost = baseUrl.contains('192.168.0.6')
              ? 'http://127.0.0.1:5200'
              : 'http://192.168.0.6:5200';
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
          final fallbackHost = baseUrl.contains('192.168.0.6')
              ? 'http://127.0.0.1:5200'
              : 'http://192.168.0.6:5200';
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

  Future<Map<String, int>> getNotificationCounts() async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res = await dio.get('/notifications', queryParameters: {'limit': 1});
      if (res.data is Map) {
        final unread = (res.data['unread_count'] as num?)?.toInt() ?? 0;
        final unactioned = (res.data['unactioned_count'] as num?)?.toInt() ?? 0;
        final total = (res.data['total_pending_count'] as num?)?.toInt() ?? (unread + unactioned);
        return {'unread': unread, 'unactioned': unactioned, 'total': total};
      }
    } catch (_) {}
    return {'unread': 0, 'unactioned': 0, 'total': 0};
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

  Future<Either<Map, List<IncidentNewsModel>>> getIncidents({int limit = 20, String? category}) async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      final params = <String, dynamic>{'limit': limit};
      if (category != null && category.isNotEmpty) {
        params['category'] = category;
      }
      var res = await dio.get('/incidents', queryParameters: params);
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

  Future<Either<Map, IncidentNewsModel>> getLatestIncident() async {
    try {
      dio.options.headers['Authorization'] = 'Bearer $getToken';
      var res = await dio.get('/incidents/latest');
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
          final fallbackHost = baseUrl.contains('192.168.0.6')
              ? 'http://127.0.0.1:5200'
              : 'http://192.168.0.6:5200';
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
          final fallbackHost = baseUrl.contains('192.168.0.6')
              ? 'http://127.0.0.1:5200'
              : 'http://192.168.0.6:5200';
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

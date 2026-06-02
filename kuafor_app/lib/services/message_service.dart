import 'package:dio/dio.dart';
import 'auth_service.dart';

class MessageService {
  static const String _base = 'https://kuafor-019f.onrender.com/api/Messages';
  final AuthService _authService = AuthService();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<Options> _options() async {
    final token = await _authService.getToken();
    return Options(
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  Future<List<Map<String, dynamic>>> getCustomerThreads(int customerId) async {
    try {
      final res = await _dio.get(
        '$_base/customer/$customerId',
        options: await _options(),
      );
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getSalonThreads(int salonId) async {
    try {
      final res = await _dio.get(
        '$_base/salon/$salonId',
        options: await _options(),
      );
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getThreadMessages({
    required int salonId,
    required int customerId,
    required String type,
  }) async {
    try {
      final res = await _dio.get(
        '$_base/thread',
        queryParameters: {
          'salonId': salonId,
          'customerId': customerId,
          'type': type,
        },
        options: await _options(),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final messages = (res.data as Map)['messages'];
        if (messages is List) return List<Map<String, dynamic>>.from(messages);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> sendMessage({
    required int salonId,
    required int customerId,
    required int senderId,
    required String content,
    required String type,
  }) async {
    try {
      final res = await _dio.post(
        _base,
        data: {
          'salonId': salonId,
          'customerId': customerId,
          'senderId': senderId,
          'content': content,
          'type': type,
        },
        options: await _options(),
      );
      if (res.statusCode == 200 && res.data is Map) {
        return Map<String, dynamic>.from(res.data);
      }
    } catch (_) {}
    return null;
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class CampaignService {
  static const String _base = 'https://kuaforapi.onrender.com/api';

  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>> getCampaigns() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/Campaign'),
        headers: await _headers(),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getSalonCampaigns(int salonId) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/Campaign/salon/$salonId'),
        headers: await _headers(),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  Future<({bool success, String? error})> createCampaign({
    required int salonId,
    required String title,
    required String description,
    String? code,
    required int discountPercent,
    required DateTime startDate,
    DateTime? endDate,
    int usageLimit = 100,
  }) async {
    try {
      final body = {
        if (salonId > 0) 'salonId': salonId,
        'title': title.trim(),
        'description': description.trim(),
        if (code != null && code.trim().isNotEmpty)
          'code': code.trim().toUpperCase(),
        'discountPercent': discountPercent,
        'startDate': startDate.toUtc().toIso8601String(),
        'endDate': endDate?.toUtc().toIso8601String(),
        'usageLimit': usageLimit,
        'isActive': true,
      };

      final res = await http.post(
        Uri.parse('$_base/Campaign'),
        headers: await _headers(),
        body: jsonEncode(body),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        return (success: true, error: null);
      }

      return (
        success: false,
        error: _extractErrorMessage(
          res.body,
          'Sunucu hatası: ${res.statusCode}',
        ),
      );
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  Future<({Map<String, dynamic>? campaign, String? error})> validateCode(
    String code,
  ) async {
    final trimmedCode = code.trim();

    if (trimmedCode.isEmpty) {
      return (campaign: null, error: 'Kampanya kodu giriniz');
    }

    try {
      final uri = Uri.parse('$_base/Campaign/validate-code').replace(
        queryParameters: {
          'code': trimmedCode.toUpperCase(),
        },
      );

      final res = await http.get(
        uri,
        headers: await _headers(),
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;

        if (decoded['success'] == true && decoded['campaign'] != null) {
          return (
            campaign: decoded['campaign'] as Map<String, dynamic>,
            error: null,
          );
        }

        return (
          campaign: decoded,
          error: null,
        );
      }

      return (
        campaign: null,
        error: _extractErrorMessage(res.body, 'Kod geçersiz'),
      );
    } catch (_) {
      return (campaign: null, error: 'Bağlantı hatası');
    }
  }

  Future<bool> deactivateCampaign(int campaignId) async {
    try {
      final res = await http.put(
        Uri.parse('$_base/Campaign/$campaignId/deactivate'),
        headers: await _headers(),
      );

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCampaign(int campaignId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_base/Campaign/$campaignId'),
        headers: await _headers(),
      );

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  String _extractErrorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ??
            decoded['detail']?.toString() ??
            fallback;
      }

      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}
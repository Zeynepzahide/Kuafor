import 'package:dio/dio.dart';
import '../models/recommended_salon_model.dart';

class RecommendationService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://kuafor-019f.onrender.com/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Future<List<RecommendedSalonModel>> getRecommendedSalons() async {
    final response = await _dio.get('/Salon/recommended');

    final List data = response.data;

    return data
        .map((item) => RecommendedSalonModel.fromJson(item))
        .toList();
  }
}
class RecommendedSalonModel {
  final int salonId;
  final String salonName;
  final String address;
  final double recommendationScore;
  final String recommendationReason;

  RecommendedSalonModel({
    required this.salonId,
    required this.salonName,
    required this.address,
    required this.recommendationScore,
    required this.recommendationReason,
  });

  factory RecommendedSalonModel.fromJson(Map<String, dynamic> json) {
    return RecommendedSalonModel(
      salonId: json['salonId'] ?? 0,
      salonName: json['salonName'] ?? '',
      address: json['address'] ?? '',
      recommendationScore:
          (json['recommendationScore'] as num?)?.toDouble() ?? 0,
      recommendationReason: json['recommendationReason'] ?? '',
    );
  }
}
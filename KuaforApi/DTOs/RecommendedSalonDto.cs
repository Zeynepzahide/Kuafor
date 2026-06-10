namespace KuaforBackend.DTOs
{
    public class RecommendedSalonDto
    {
        public int SalonId { get; set; }
        public string SalonName { get; set; } = string.Empty;
        public string? Address { get; set; }

        public double? Latitude { get; set; }
        public double? Longitude { get; set; }

        public double AverageRating { get; set; }
        public int ReviewCount { get; set; }
        public int CampaignCount { get; set; }
        public int ServiceCount { get; set; }

        public double RecommendationScore { get; set; }
        public string RecommendationReason { get; set; } = string.Empty;
    }
}
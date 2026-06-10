using KuaforApi.Data;
using KuaforApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace KuaforApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SalonController : ControllerBase
{
    private readonly AppDbContext _context;

    public SalonController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<IActionResult> GetSalons()
    {
        var salons = await _context.Salons
            .Select(s => new
            {
                s.Id,
                s.Name,
                s.Address,
                s.Description,
                s.ImageUrl,
                s.OwnerId,
                s.Latitude,
                s.Longitude,
                averageRating = _context.Reviews
                    .Where(r => r.SalonId == s.Id)
                    .Select(r => (double?)r.Rating)
                    .Average() ?? 0
            })
            .ToListAsync();

        return Ok(salons);
    }

    [HttpGet("nearby")]
    public async Task<IActionResult> GetNearbySalons(
        [FromQuery] double lat,
        [FromQuery] double lng,
        [FromQuery] double radius = 10.0)
    {
        var salons = await _context.Salons
            .Where(s => s.Latitude != null && s.Longitude != null)
            .Select(s => new
            {
                s.Id,
                s.Name,
                s.Address,
                s.Description,
                s.ImageUrl,
                s.OwnerId,
                s.Latitude,
                s.Longitude,
                averageRating = _context.Reviews
                    .Where(r => r.SalonId == s.Id)
                    .Select(r => (double?)r.Rating)
                    .Average() ?? 0
            })
            .ToListAsync();

        var nearby = salons
            .Select(s => new
            {
                s.Id,
                s.Name,
                s.Address,
                s.Description,
                s.ImageUrl,
                s.OwnerId,
                s.Latitude,
                s.Longitude,
                s.averageRating,
                DistanceKm = HaversineDistance(lat, lng, s.Latitude!.Value, s.Longitude!.Value)
            })
            .Where(s => s.DistanceKm <= radius)
            .OrderBy(s => s.DistanceKm)
            .ToList();

        return Ok(nearby);
    }

    // YENİ: Yapay zeka destekli / kural tabanlı salon öneri endpoint'i
    [HttpGet("recommended")]
    public async Task<IActionResult> GetRecommendedSalons(
        [FromQuery] double? latitude,
        [FromQuery] double? longitude,
        [FromQuery] string? serviceName)
    {
        var salons = await _context.Salons
            .Select(s => new
            {
                s.Id,
                s.Name,
                s.Address,
                s.Description,
                s.ImageUrl,
                s.OwnerId,
                s.Latitude,
                s.Longitude
            })
            .ToListAsync();

        var recommendedSalons = new List<RecommendedSalonDto>();

        foreach (var salon in salons)
        {
            double distanceKm = 0;
            double distanceScore = 50;

            if (latitude.HasValue &&
                longitude.HasValue &&
                salon.Latitude.HasValue &&
                salon.Longitude.HasValue)
            {
                distanceKm = HaversineDistance(
                    latitude.Value,
                    longitude.Value,
                    salon.Latitude.Value,
                    salon.Longitude.Value
                );

                distanceScore = Math.Max(0, 100 - (distanceKm * 10));
            }

            double averageRating = await _context.Reviews
                .Where(r => r.SalonId == salon.Id)
                .Select(r => (double?)r.Rating)
                .AverageAsync() ?? 0;

            int reviewCount = await _context.Reviews
                .CountAsync(r => r.SalonId == salon.Id);

            int campaignCount = await _context.Campaigns
                .CountAsync(c => c.SalonId == salon.Id);

            int serviceCount = await _context.Services
                .CountAsync(s => s.SalonId == salon.Id);

            double ratingScore = averageRating * 20;

            double reviewScore = Math.Min(reviewCount * 5, 100);

            double campaignScore = campaignCount > 0 ? 100 : 0;

            double serviceMatchScore = 50;

            if (!string.IsNullOrWhiteSpace(serviceName))
            {
                bool hasMatchingService = await _context.Services
                    .AnyAsync(s =>
                        s.SalonId == salon.Id &&
                        s.Name.ToLower().Contains(serviceName.ToLower()));

                serviceMatchScore = hasMatchingService ? 100 : 20;
            }

            double finalScore =
                (distanceScore * 0.35) +
                (ratingScore * 0.25) +
                (reviewScore * 0.15) +
                (serviceMatchScore * 0.15) +
                (campaignScore * 0.10);

            string reason = BuildRecommendationReason(
                distanceKm,
                averageRating,
                campaignCount,
                serviceMatchScore
            );

            recommendedSalons.Add(new RecommendedSalonDto
            {
                SalonId = salon.Id,
                SalonName = salon.Name,
                Address = salon.Address,
                Description = salon.Description,
                ImageUrl = salon.ImageUrl,
                OwnerId = salon.OwnerId,
                Latitude = salon.Latitude,
                Longitude = salon.Longitude,
                AverageRating = Math.Round(averageRating, 1),
                ReviewCount = reviewCount,
                CampaignCount = campaignCount,
                ServiceCount = serviceCount,
                DistanceKm = Math.Round(distanceKm, 2),
                RecommendationScore = Math.Round(finalScore, 2),
                RecommendationReason = reason
            });
        }

        var result = recommendedSalons
            .OrderByDescending(x => x.RecommendationScore)
            .Take(10)
            .ToList();

        return Ok(result);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetSalon(int id)
    {
        var salon = await _context.Salons
            .Where(s => s.Id == id)
            .Select(s => new
            {
                s.Id,
                s.Name,
                s.Address,
                s.Description,
                s.ImageUrl,
                s.OwnerId,
                s.Latitude,
                s.Longitude
            })
            .FirstOrDefaultAsync();

        if (salon == null)
            return NotFound(new { message = "Salon bulunamadı." });

        var salonServices = await _context.Services
            .Where(sv => sv.SalonId == id && sv.StylistId == null)
            .Select(sv => new ServiceDto
            {
                Id = sv.Id,
                Name = sv.Name,
                Price = sv.Price,
                DurationMinutes = sv.DurationMinutes,
                StylistName = null
            })
            .ToListAsync();

        var stylistSalonServices = await _context.Services
            .Where(sv => sv.SalonId == id && sv.StylistId != null)
            .Join(_context.Users,
                sv => sv.StylistId,
                u => u.Id,
                (sv, u) => new ServiceDto
                {
                    Id = sv.Id,
                    Name = sv.Name,
                    Price = sv.Price,
                    DurationMinutes = sv.DurationMinutes,
                    StylistName = u.FullName
                })
            .ToListAsync();

        var employeeUserIds = await _context.Employees
            .Where(e => e.SalonId == id)
            .Select(e => e.UserId)
            .ToListAsync();

        var legacyStylistServices = await _context.Services
            .Where(sv =>
                sv.StylistId != null &&
                sv.SalonId == null &&
                employeeUserIds.Contains(sv.StylistId!.Value))
            .Join(_context.Users,
                sv => sv.StylistId,
                u => u.Id,
                (sv, u) => new ServiceDto
                {
                    Id = sv.Id,
                    Name = sv.Name,
                    Price = sv.Price,
                    DurationMinutes = sv.DurationMinutes,
                    StylistName = u.FullName
                })
            .ToListAsync();

        var allServices = salonServices
            .Concat(stylistSalonServices)
            .Concat(legacyStylistServices)
            .ToList();

        return Ok(new
        {
            salon.Id,
            salon.Name,
            salon.Address,
            salon.Description,
            salon.ImageUrl,
            salon.OwnerId,
            salon.Latitude,
            salon.Longitude,
            services = allServices
        });
    }

    [HttpGet("owner/{ownerId}")]
    public async Task<IActionResult> GetSalonByOwner(int ownerId)
    {
        var salon = await _context.Salons
            .Where(s => s.OwnerId == ownerId)
            .Select(s => new
            {
                s.Id,
                s.Name,
                s.Address,
                s.Description,
                s.ImageUrl,
                s.OwnerId,
                s.Latitude,
                s.Longitude
            })
            .FirstOrDefaultAsync();

        if (salon == null)
            return NotFound(new { message = "Bu kullanıcıya ait salon bulunamadı." });

        return Ok(salon);
    }

    [HttpGet("stylist/{stylistId}")]
    public async Task<IActionResult> GetSalonByStylist(int stylistId)
    {
        var employee = await _context.Employees
            .Where(e => e.UserId == stylistId)
            .FirstOrDefaultAsync();

        if (employee == null)
            return NotFound(new { message = "Bu stiliste ait salon bulunamadı." });

        var salon = await _context.Salons
            .Where(s => s.Id == employee.SalonId)
            .Select(s => new
            {
                s.Id,
                s.Name,
                s.Address,
                s.Description,
                s.ImageUrl,
                s.OwnerId,
                s.Latitude,
                s.Longitude
            })
            .FirstOrDefaultAsync();

        if (salon == null)
            return NotFound(new { message = "Salon bulunamadı." });

        return Ok(salon);
    }

    [HttpPost]
    public async Task<IActionResult> CreateSalon([FromBody] Salon salon)
    {
        var ownerExists = await _context.Users.AnyAsync(u => u.Id == salon.OwnerId);

        if (!ownerExists)
            return BadRequest(new { message = "Kullanıcı bulunamadı." });

        _context.Salons.Add(salon);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            salon.Id,
            salon.Name,
            salon.Address,
            salon.Description,
            salon.ImageUrl,
            salon.OwnerId,
            salon.Latitude,
            salon.Longitude
        });
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateSalon(int id, [FromBody] UpdateSalonRequest req)
    {
        var salon = await _context.Salons.FindAsync(id);

        if (salon == null)
            return NotFound(new { message = "Salon bulunamadı." });

        if (req.Name != null) salon.Name = req.Name;
        if (req.Address != null) salon.Address = req.Address;
        if (req.Description != null) salon.Description = req.Description;
        if (req.ImageUrl != null) salon.ImageUrl = req.ImageUrl;
        if (req.Latitude != null) salon.Latitude = req.Latitude;
        if (req.Longitude != null) salon.Longitude = req.Longitude;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            salon.Id,
            salon.Name,
            salon.Address,
            salon.Description,
            salon.ImageUrl,
            salon.OwnerId,
            salon.Latitude,
            salon.Longitude
        });
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteSalon(int id)
    {
        var salon = await _context.Salons.FindAsync(id);

        if (salon == null)
            return NotFound(new { message = "Salon bulunamadı." });

        _context.Salons.Remove(salon);
        await _context.SaveChangesAsync();

        return Ok(new { message = "Salon silindi." });
    }

    private static double HaversineDistance(double lat1, double lon1, double lat2, double lon2)
    {
        const double R = 6371.0;

        var dLat = ToRad(lat2 - lat1);
        var dLon = ToRad(lon2 - lon1);

        var a =
            Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
            Math.Cos(ToRad(lat1)) *
            Math.Cos(ToRad(lat2)) *
            Math.Sin(dLon / 2) *
            Math.Sin(dLon / 2);

        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));

        return R * c;
    }

    private static double ToRad(double deg)
    {
        return deg * Math.PI / 180.0;
    }

    private static string BuildRecommendationReason(
        double distanceKm,
        double averageRating,
        int campaignCount,
        double serviceMatchScore)
    {
        var reasons = new List<string>();

        if (distanceKm > 0 && distanceKm <= 5)
            reasons.Add("konumuna yakın");

        if (averageRating >= 4)
            reasons.Add("puanı yüksek");

        if (campaignCount > 0)
            reasons.Add("kampanyalı hizmet sunuyor");

        if (serviceMatchScore >= 100)
            reasons.Add("aradığın hizmetle uyumlu");

        if (!reasons.Any())
            return "Genel puanlama kriterlerine göre önerildi.";

        return "Bu salon sana önerildi çünkü " + string.Join(", ", reasons) + ".";
    }
}

public class UpdateSalonRequest
{
    public string? Name { get; set; }
    public string? Address { get; set; }
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
}

public class ServiceDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public int DurationMinutes { get; set; }
    public string? StylistName { get; set; }
}

public class RecommendedSalonDto
{
    public int SalonId { get; set; }
    public string SalonName { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }
    public int OwnerId { get; set; }

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }

    public double AverageRating { get; set; }
    public int ReviewCount { get; set; }
    public int CampaignCount { get; set; }
    public int ServiceCount { get; set; }

    public double DistanceKm { get; set; }
    public double RecommendationScore { get; set; }
    public string RecommendationReason { get; set; } = string.Empty;
}
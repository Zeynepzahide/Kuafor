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

    // Yapay zeka destekli / kural tabanlı salon öneri endpoint'i
    // Bu sürüm Render'da hata vermemesi için sadece Salons tablosunu kullanır.
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

            double searchScore = 50;

            if (!string.IsNullOrWhiteSpace(serviceName))
            {
                string search = serviceName.ToLower();

                bool matchesSearch =
                    (!string.IsNullOrWhiteSpace(salon.Name) &&
                     salon.Name.ToLower().Contains(search)) ||
                    (!string.IsNullOrWhiteSpace(salon.Description) &&
                     salon.Description.ToLower().Contains(search)) ||
                    (!string.IsNullOrWhiteSpace(salon.Address) &&
                     salon.Address.ToLower().Contains(search));

                searchScore = matchesSearch ? 100 : 40;
            }

            double profileScore = 0;

            if (!string.IsNullOrWhiteSpace(salon.Name))
                profileScore += 25;

            if (!string.IsNullOrWhiteSpace(salon.Address))
                profileScore += 25;

            if (!string.IsNullOrWhiteSpace(salon.Description))
                profileScore += 25;

            if (!string.IsNullOrWhiteSpace(salon.ImageUrl))
                profileScore += 25;

            double finalScore =
                (distanceScore * 0.50) +
                (searchScore * 0.30) +
                (profileScore * 0.20);

            string reason = BuildSimpleRecommendationReason(
                distanceKm,
                salon.Name,
                salon.Address,
                salon.Description,
                salon.ImageUrl,
                serviceName
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

                AverageRating = 0,
                ReviewCount = 0,
                CampaignCount = 0,
                ServiceCount = 0,

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

    private static string BuildSimpleRecommendationReason(
        double distanceKm,
        string? salonName,
        string? address,
        string? description,
        string? imageUrl,
        string? serviceName)
    {
        var reasons = new List<string>();

        if (distanceKm > 0 && distanceKm <= 5)
            reasons.Add("konumuna yakın");

        if (!string.IsNullOrWhiteSpace(description))
            reasons.Add("salon bilgileri tamamlanmış");

        if (!string.IsNullOrWhiteSpace(imageUrl))
            reasons.Add("görsel bilgisi mevcut");

        if (!string.IsNullOrWhiteSpace(address))
            reasons.Add("adres bilgisi mevcut");

        if (!string.IsNullOrWhiteSpace(serviceName))
        {
            string search = serviceName.ToLower();

            bool matchesSearch =
                (!string.IsNullOrWhiteSpace(salonName) &&
                 salonName.ToLower().Contains(search)) ||
                (!string.IsNullOrWhiteSpace(description) &&
                 description.ToLower().Contains(search)) ||
                (!string.IsNullOrWhiteSpace(address) &&
                 address.ToLower().Contains(search));

            if (matchesSearch)
                reasons.Add("arama kriterinle uyumlu");
        }

        if (!reasons.Any())
            return "Genel salon bilgilerine göre önerildi.";

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
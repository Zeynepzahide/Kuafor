using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using KuaforApi.Data;
using KuaforApi.Models;

namespace KuaforApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CampaignController : ControllerBase
{
    private readonly AppDbContext _context;

    public CampaignController(AppDbContext context)
    {
        _context = context;
    }

    // GET: api/Campaign
    [HttpGet]
    public async Task<IActionResult> GetAllCampaigns()
    {
        var campaigns = await _context.Campaigns
            .Where(c => c.IsActive)
            .OrderByDescending(c => c.StartDate)
            .Select(c => new
            {
                c.Id,
                c.Title,
                c.Description,
                c.Code,
                c.DiscountPercent,
                c.CreatedAt,
                c.IsActive,
                c.StartDate,
                c.EndDate,
                c.UsageLimit,
                c.UsedCount,
                c.SalonId
            })
            .ToListAsync();

        return Ok(campaigns);
    }

    // GET: api/Campaign/salon/5
    [HttpGet("salon/{salonId}")]
    public async Task<IActionResult> GetSalonCampaigns(int salonId)
    {
        var campaigns = await _context.Campaigns
            .Where(c => c.SalonId == salonId && c.IsActive)
            .OrderByDescending(c => c.StartDate)
            .Select(c => new
            {
                c.Id,
                c.Title,
                c.Description,
                c.Code,
                c.DiscountPercent,
                c.CreatedAt,
                c.IsActive,
                c.StartDate,
                c.EndDate,
                c.UsageLimit,
                c.UsedCount,
                c.SalonId
            })
            .ToListAsync();

        return Ok(campaigns);
    }

    // GET: api/Campaign/5
    [HttpGet("{id}")]
    public async Task<IActionResult> GetCampaign(int id)
    {
        var campaign = await _context.Campaigns
            .Where(c => c.Id == id)
            .Select(c => new
            {
                c.Id,
                c.Title,
                c.Description,
                c.Code,
                c.DiscountPercent,
                c.CreatedAt,
                c.IsActive,
                c.StartDate,
                c.EndDate,
                c.UsageLimit,
                c.UsedCount,
                c.SalonId
            })
            .FirstOrDefaultAsync();

        if (campaign == null)
        {
            return NotFound(new
            {
                message = "Kampanya bulunamadı."
            });
        }

        return Ok(campaign);
    }

    // POST: api/Campaign
    [HttpPost]
    public async Task<IActionResult> CreateCampaign([FromBody] CampaignRequest request)
    {
        if (request == null)
        {
            return BadRequest(new
            {
                message = "Kampanya bilgileri alınamadı."
            });
        }

        if (string.IsNullOrWhiteSpace(request.Title))
        {
            return BadRequest(new
            {
                message = "Kampanya başlığı zorunludur."
            });
        }

        if (string.IsNullOrWhiteSpace(request.Description))
        {
            return BadRequest(new
            {
                message = "Kampanya açıklaması zorunludur."
            });
        }

        if (request.DiscountPercent < 0 || request.DiscountPercent > 100)
        {
            return BadRequest(new
            {
                message = "İndirim oranı 0-100 arasında olmalıdır."
            });
        }

        var startDate = request.StartDate ?? DateTime.UtcNow;
        var endDate = request.EndDate;

        if (endDate != null && endDate < startDate)
        {
            return BadRequest(new
            {
                message = "Bitiş tarihi başlangıçtan önce olamaz."
            });
        }

        string? normalizedCode = null;

        if (!string.IsNullOrWhiteSpace(request.Code))
        {
            normalizedCode = request.Code.Trim().ToUpperInvariant();

            var codeExists = await _context.Campaigns.AnyAsync(c =>
                c.Code != null &&
                c.Code.ToUpper() == normalizedCode &&
                c.IsActive);

            if (codeExists)
            {
                return BadRequest(new
                {
                    message = "Bu kampanya kodu zaten kullanılıyor."
                });
            }
        }

        int usageLimit = request.UsageLimit <= 0 ? 100 : request.UsageLimit;

        int? salonId = request.SalonId;

        if (salonId.HasValue && salonId.Value <= 0)
        {
            salonId = null;
        }

        if (salonId.HasValue)
        {
            var salonExists = await _context.Salons.AnyAsync(s => s.Id == salonId.Value);

            if (!salonExists)
            {
                salonId = null;
            }
        }

        var campaign = new Campaign
        {
            Title = request.Title.Trim(),
            Description = request.Description.Trim(),
            Code = normalizedCode,
            DiscountPercent = request.DiscountPercent,
            CreatedAt = DateTime.UtcNow,
            IsActive = true,
            StartDate = DateTime.SpecifyKind(startDate, DateTimeKind.Utc),
            EndDate = endDate.HasValue
                ? DateTime.SpecifyKind(endDate.Value, DateTimeKind.Utc)
                : null,
            UsageLimit = usageLimit,
            UsedCount = 0,
            SalonId = salonId
        };

        try
        {
            _context.Campaigns.Add(campaign);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Kampanya başarıyla oluşturuldu.",
                campaign = new
                {
                    campaign.Id,
                    campaign.Title,
                    campaign.Description,
                    campaign.Code,
                    campaign.DiscountPercent,
                    campaign.CreatedAt,
                    campaign.IsActive,
                    campaign.StartDate,
                    campaign.EndDate,
                    campaign.UsageLimit,
                    campaign.UsedCount,
                    campaign.SalonId
                }
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new
            {
                message = "Kampanya kaydedilirken hata oluştu.",
                detail = ex.InnerException?.Message ?? ex.Message
            });
        }
    }

    // GET: api/Campaign/validate-code?code=BAKIM15
    [HttpGet("validate-code")]
    public async Task<IActionResult> ValidateCode([FromQuery] string code)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            return BadRequest(new
            {
                message = "Kampanya kodu zorunludur."
            });
        }

        var now = DateTime.UtcNow;
        var normalized = code.Trim().ToUpperInvariant();

        var campaign = await _context.Campaigns
            .Where(c => c.IsActive)
            .Where(c => c.Code != null && c.Code.ToUpper() == normalized)
            .Where(c => c.StartDate <= now)
            .Where(c => c.EndDate == null || c.EndDate >= now)
            .OrderByDescending(c => c.DiscountPercent)
            .Select(c => new
            {
                c.Id,
                c.Title,
                c.Description,
                c.Code,
                c.DiscountPercent,
                c.StartDate,
                c.EndDate,
                c.SalonId,
                c.UsageLimit,
                c.UsedCount
            })
            .FirstOrDefaultAsync();

        if (campaign == null)
        {
            return NotFound(new
            {
                message = "Geçerli kampanya bulunamadı."
            });
        }

        if (campaign.UsedCount >= campaign.UsageLimit)
        {
            return BadRequest(new
            {
                message = "Kampanya kullanım limiti doldu."
            });
        }

        return Ok(new
        {
            success = true,
            campaign
        });
    }

    // PUT: api/Campaign/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateCampaign(
        int id,
        [FromBody] CampaignRequest request)
    {
        var campaign = await _context.Campaigns.FindAsync(id);

        if (campaign == null)
        {
            return NotFound(new
            {
                message = "Kampanya bulunamadı."
            });
        }

        if (string.IsNullOrWhiteSpace(request.Title))
        {
            return BadRequest(new
            {
                message = "Kampanya başlığı zorunludur."
            });
        }

        if (request.DiscountPercent < 0 || request.DiscountPercent > 100)
        {
            return BadRequest(new
            {
                message = "İndirim oranı 0-100 arasında olmalıdır."
            });
        }

        var startDate = request.StartDate ?? campaign.StartDate;
        var endDate = request.EndDate;

        if (endDate != null && endDate < startDate)
        {
            return BadRequest(new
            {
                message = "Bitiş tarihi başlangıçtan önce olamaz."
            });
        }

        campaign.Title = request.Title.Trim();
        campaign.Description = request.Description?.Trim() ?? "";
        campaign.DiscountPercent = request.DiscountPercent;
        campaign.StartDate = DateTime.SpecifyKind(startDate, DateTimeKind.Utc);
        campaign.EndDate = endDate.HasValue
            ? DateTime.SpecifyKind(endDate.Value, DateTimeKind.Utc)
            : null;
        campaign.UsageLimit = request.UsageLimit <= 0 ? campaign.UsageLimit : request.UsageLimit;

        if (!string.IsNullOrWhiteSpace(request.Code))
        {
            campaign.Code = request.Code.Trim().ToUpperInvariant();
        }

        if (request.SalonId.HasValue && request.SalonId.Value > 0)
        {
            campaign.SalonId = request.SalonId.Value;
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Kampanya güncellendi.",
            campaign
        });
    }

    // DELETE: api/Campaign/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteCampaign(int id)
    {
        var campaign = await _context.Campaigns.FindAsync(id);

        if (campaign == null)
        {
            return NotFound(new
            {
                message = "Kampanya bulunamadı."
            });
        }

        _context.Campaigns.Remove(campaign);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Kampanya silindi."
        });
    }

    // PUT: api/Campaign/5/deactivate
    [HttpPut("{id}/deactivate")]
    public async Task<IActionResult> DeactivateCampaign(int id)
    {
        var campaign = await _context.Campaigns.FindAsync(id);

        if (campaign == null)
        {
            return NotFound(new
            {
                message = "Kampanya bulunamadı."
            });
        }

        campaign.IsActive = false;
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Kampanya devre dışı bırakıldı."
        });
    }
}

public class CampaignRequest
{
    public string Title { get; set; } = "";

    public string Description { get; set; } = "";

    public string? Code { get; set; }

    public int DiscountPercent { get; set; }

    public DateTime? StartDate { get; set; }

    public DateTime? EndDate { get; set; }

    public int UsageLimit { get; set; } = 100;

    public int? SalonId { get; set; }
}
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
            .ToListAsync();

        return Ok(campaigns);
    }

    // GET: api/Campaign/5
    [HttpGet("{id}")]
    public async Task<IActionResult> GetCampaign(int id)
    {
        var campaign = await _context.Campaigns.FindAsync(id);

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
    public async Task<IActionResult> CreateCampaign([FromBody] Campaign campaign)
    {
        if (campaign == null)
        {
            return BadRequest(new
            {
                message = "Kampanya bilgileri alınamadı."
            });
        }

        if (string.IsNullOrWhiteSpace(campaign.Title))
        {
            return BadRequest(new
            {
                message = "Kampanya başlığı zorunludur."
            });
        }

        if (string.IsNullOrWhiteSpace(campaign.Description))
        {
            return BadRequest(new
            {
                message = "Kampanya açıklaması zorunludur."
            });
        }

        if (campaign.DiscountPercent < 0 || campaign.DiscountPercent > 100)
        {
            return BadRequest(new
            {
                message = "İndirim oranı 0-100 arasında olmalıdır."
            });
        }

        if (campaign.StartDate == default)
        {
            campaign.StartDate = DateTime.UtcNow;
        }

        if (campaign.EndDate != null && campaign.EndDate < campaign.StartDate)
        {
            return BadRequest(new
            {
                message = "Bitiş tarihi başlangıçtan önce olamaz."
            });
        }

        if (!string.IsNullOrWhiteSpace(campaign.Code))
        {
            campaign.Code = campaign.Code.Trim().ToUpperInvariant();

            var codeExists = await _context.Campaigns.AnyAsync(c =>
                c.Code != null &&
                c.Code.ToUpper() == campaign.Code &&
                c.IsActive);

            if (codeExists)
            {
                return BadRequest(new
                {
                    message = "Bu kampanya kodu zaten kullanılıyor."
                });
            }
        }

        if (campaign.SalonId.HasValue)
        {
            var salonExists = await _context.Salons.AnyAsync(
                s => s.Id == campaign.SalonId.Value
            );

            if (!salonExists)
            {
                campaign.SalonId = null;
            }
        }

        if (campaign.UsageLimit <= 0)
        {
            campaign.UsageLimit = 100;
        }

        campaign.UsedCount = 0;
        campaign.CreatedAt = DateTime.UtcNow;
        campaign.IsActive = true;

        campaign.StartDate = DateTime.SpecifyKind(campaign.StartDate, DateTimeKind.Utc);

        if (campaign.EndDate.HasValue)
        {
            campaign.EndDate = DateTime.SpecifyKind(campaign.EndDate.Value, DateTimeKind.Utc);
        }

        try
        {
            _context.Campaigns.Add(campaign);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Kampanya başarıyla oluşturuldu.",
                campaign
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
            campaign = new
            {
                campaign.Id,
                campaign.Title,
                campaign.Description,
                campaign.Code,
                campaign.DiscountPercent,
                campaign.StartDate,
                campaign.EndDate,
                campaign.SalonId,
                campaign.UsageLimit,
                campaign.UsedCount
            }
        });
    }

    // PUT: api/Campaign/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateCampaign(int id, [FromBody] Campaign campaign)
    {
        if (campaign == null)
        {
            return BadRequest(new
            {
                message = "Kampanya bilgileri alınamadı."
            });
        }

        var existing = await _context.Campaigns.FindAsync(id);

        if (existing == null)
        {
            return NotFound(new
            {
                message = "Kampanya bulunamadı."
            });
        }

        if (string.IsNullOrWhiteSpace(campaign.Title))
        {
            return BadRequest(new
            {
                message = "Kampanya başlığı zorunludur."
            });
        }

        if (campaign.DiscountPercent < 0 || campaign.DiscountPercent > 100)
        {
            return BadRequest(new
            {
                message = "İndirim oranı 0-100 arasında olmalıdır."
            });
        }

        if (campaign.EndDate != null && campaign.EndDate < campaign.StartDate)
        {
            return BadRequest(new
            {
                message = "Bitiş tarihi başlangıçtan önce olamaz."
            });
        }

        existing.Title = campaign.Title.Trim();
        existing.Description = campaign.Description?.Trim() ?? "";
        existing.DiscountPercent = campaign.DiscountPercent;
        existing.StartDate = DateTime.SpecifyKind(campaign.StartDate, DateTimeKind.Utc);
        existing.EndDate = campaign.EndDate.HasValue
            ? DateTime.SpecifyKind(campaign.EndDate.Value, DateTimeKind.Utc)
            : null;

        existing.UsageLimit = campaign.UsageLimit <= 0
            ? existing.UsageLimit
            : campaign.UsageLimit;

        if (!string.IsNullOrWhiteSpace(campaign.Code))
        {
            existing.Code = campaign.Code.Trim().ToUpperInvariant();
        }

        if (campaign.SalonId.HasValue)
        {
            var salonExists = await _context.Salons.AnyAsync(
                s => s.Id == campaign.SalonId.Value
            );

            existing.SalonId = salonExists ? campaign.SalonId : null;
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Kampanya güncellendi.",
            campaign = existing
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
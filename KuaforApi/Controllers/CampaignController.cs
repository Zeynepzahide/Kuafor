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


    [HttpGet]
    public async Task<IActionResult> GetAllCampaigns()
    {
        var campaigns = await _context.Campaigns
            .Where(c => c.IsActive)
            .OrderByDescending(c => c.StartDate)
            .ToListAsync();

        return Ok(campaigns);
    }


    [HttpGet("salon/{salonId}")]
    public async Task<IActionResult> GetSalonCampaigns(
        int salonId)
    {
        var campaigns = await _context.Campaigns

            .Where(c =>
                c.SalonId == salonId &&
                c.IsActive)

            .OrderByDescending(c => c.StartDate)

            .ToListAsync();

        return Ok(campaigns);
    }


    [HttpGet("{id}")]
    public async Task<IActionResult> GetCampaign(
        int id)
    {
        var campaign =
            await _context.Campaigns
                .FindAsync(id);

        if (campaign == null)
        {
            return NotFound(new
            {
                message =
                    "Kampanya bulunamadı."
            });
        }

        return Ok(campaign);
    }

    [HttpPost]
    public async Task<IActionResult> CreateCampaign(
        [FromBody] Campaign campaign)
    {

        if (string.IsNullOrWhiteSpace(
            campaign.Title))
        {
            return BadRequest(new
            {
                message =
                    "Kampanya başlığı zorunludur."
            });
        }

        if (campaign.DiscountPercent < 0 ||
            campaign.DiscountPercent > 100)
        {
            return BadRequest(new
            {
                message =
                    "İndirim oranı 0-100 arasında olmalıdır."
            });
        }

        if (campaign.EndDate != null &&
            campaign.EndDate <
            campaign.StartDate)
        {
            return BadRequest(new
            {
                message =
                    "Bitiş tarihi başlangıçtan önce olamaz."
            });
        }

        if (!string.IsNullOrWhiteSpace(
            campaign.Code))
        {
            campaign.Code =
                campaign.Code
                    .Trim()
                    .ToUpperInvariant();
        }

        campaign.CreatedAt =
            DateTime.UtcNow;

        campaign.IsActive = true;

        _context.Campaigns.Add(campaign);

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message =
                "Kampanya başarıyla oluşturuldu.",

            campaign
        });
    }



    [HttpGet("validate-code")]
    public async Task<IActionResult> ValidateCode(
        [FromQuery] string code)
    {

        if (string.IsNullOrWhiteSpace(code))
        {
            return BadRequest(new
            {
                message =
                    "Kampanya kodu zorunludur."
            });
        }

        var now = DateTime.UtcNow;

        var normalized =
            code.Trim().ToUpperInvariant();

        var campaign =
            await _context.Campaigns

            .Where(c =>
                c.IsActive &&
                c.Code == normalized)

            .Where(c =>
                c.StartDate <= now &&
                (
                    c.EndDate == null ||
                    c.EndDate >= now
                )
            )

            .FirstOrDefaultAsync();


        if (campaign == null)
        {
            return NotFound(new
            {
                message =
                    "Geçerli kampanya bulunamadı."
            });
        }


        if (campaign.UsedCount >=
            campaign.UsageLimit)
        {
            return BadRequest(new
            {
                message =
                    "Kampanya kullanım limiti doldu."
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
                campaign.EndDate
            }
        });
    }


    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateCampaign(
        int id,
        [FromBody] Campaign campaign)
    {
        if (id != campaign.Id)
        {
            return BadRequest(new
            {
                message =
                    "ID eşleşmiyor."
            });
        }

        if (!string.IsNullOrWhiteSpace(
            campaign.Code))
        {
            campaign.Code =
                campaign.Code
                    .Trim()
                    .ToUpperInvariant();
        }

        _context.Entry(campaign)
            .State = EntityState.Modified;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message =
                "Kampanya güncellendi."
        });
    }

  

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteCampaign(
        int id)
    {
        var campaign =
            await _context.Campaigns
                .FindAsync(id);

        if (campaign == null)
        {
            return NotFound(new
            {
                message =
                    "Kampanya bulunamadı."
            });
        }

        _context.Campaigns.Remove(campaign);

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message =
                "Kampanya silindi."
        });
    }


    [HttpPut("{id}/deactivate")]
    public async Task<IActionResult> DeactivateCampaign(
        int id)
    {
        var campaign =
            await _context.Campaigns
                .FindAsync(id);

        if (campaign == null)
        {
            return NotFound(new
            {
                message =
                    "Kampanya bulunamadı."
            });
        }

        campaign.IsActive = false;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message =
                "Kampanya devre dışı bırakıldı."
        });
    }
}
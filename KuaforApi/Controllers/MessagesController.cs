using KuaforApi.Data;
using KuaforApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace KuaforApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MessagesController : ControllerBase
{
    private const string AppointmentThreadType = "Appointment";
    private const string InquiryThreadType = "Inquiry";
    private readonly AppDbContext _context;

    public MessagesController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("customer/{customerId}")]
    public async Task<IActionResult> GetCustomerThreads(int customerId)
    {
        var appointments = await _context.Appointments
            .Include(a => a.Salon)
            .Include(a => a.Service)
            .Where(a => a.CustomerId == customerId)
            .OrderByDescending(a => a.AppointmentDate)
            .ToListAsync();

        var threads = await BuildAppointmentThreadDtos(appointments, ownerMode: false);
        threads.AddRange(await BuildInquiryThreadDtos(customerId: customerId));
        return Ok(SortThreadDtos(threads));
    }

    [HttpGet("salon/{salonId}")]
    public async Task<IActionResult> GetSalonThreads(int salonId)
    {
        var appointments = await _context.Appointments
            .Include(a => a.Customer)
            .Include(a => a.Salon)
            .Include(a => a.Service)
            .Where(a => a.SalonId == salonId)
            .OrderByDescending(a => a.AppointmentDate)
            .ToListAsync();

        var threads = await BuildAppointmentThreadDtos(appointments, ownerMode: true);
        threads.AddRange(await BuildInquiryThreadDtos(salonId: salonId));
        return Ok(SortThreadDtos(threads));
    }

    [HttpGet("thread")]
    public async Task<IActionResult> GetThread(
        [FromQuery] int salonId,
        [FromQuery] int customerId,
        [FromQuery] string? type = null)
    {
        var threadType = await ResolveThreadType(salonId, customerId, type);
        if (threadType == AppointmentThreadType && !await HasAppointment(salonId, customerId))
            return BadRequest(new { message = "Mesajlaşmak için randevu kaydı gerekir." });

        var thread = await EnsureThread(salonId, customerId, threadType);
        var messages = await _context.ChatMessages
            .Include(m => m.Sender)
            .Where(m => m.MessageThreadId == thread.Id)
            .OrderBy(m => m.CreatedAt)
            .Select(m => new
            {
                m.Id,
                m.MessageThreadId,
                m.SenderId,
                senderName = m.Sender != null ? m.Sender.FullName : "",
                m.Content,
                m.IsRead,
                m.CreatedAt
            })
            .ToListAsync();

        return Ok(new
        {
            thread.Id,
            thread.SalonId,
            thread.CustomerId,
            thread.Type,
            messages
        });
    }

    [HttpPost]
    public async Task<IActionResult> SendMessage([FromBody] SendMessageRequest request)
    {
        if (request.SalonId <= 0 || request.CustomerId <= 0 ||
            request.SenderId <= 0 || string.IsNullOrWhiteSpace(request.Content))
        {
            return BadRequest(new { message = "Salon, müşteri, gönderen ve mesaj zorunludur." });
        }

        var threadType = await ResolveThreadType(
            request.SalonId,
            request.CustomerId,
            request.Type);

        if (threadType == AppointmentThreadType &&
            !await HasAppointment(request.SalonId, request.CustomerId))
        {
            return BadRequest(new { message = "Mesajlaşmak için randevu kaydı gerekir." });
        }

        var isParticipant = request.SenderId == request.CustomerId ||
            await _context.Salons.AnyAsync(s =>
                s.Id == request.SalonId && s.OwnerId == request.SenderId);

        if (!isParticipant)
            return Forbid();

        var thread = await EnsureThread(request.SalonId, request.CustomerId, threadType);
        var message = new ChatMessage
        {
            MessageThreadId = thread.Id,
            SenderId = request.SenderId,
            Content = request.Content.Trim(),
            CreatedAt = DateTime.UtcNow
        };

        thread.UpdatedAt = message.CreatedAt;
        _context.ChatMessages.Add(message);
        await _context.SaveChangesAsync();

        var sender = await _context.Users.FindAsync(request.SenderId);

        return Ok(new
        {
            message.Id,
            message.MessageThreadId,
            message.SenderId,
            senderName = sender?.FullName ?? "",
            message.Content,
            message.IsRead,
            message.CreatedAt
        });
    }

    private async Task<List<object>> BuildAppointmentThreadDtos(
        List<Appointment> appointments,
        bool ownerMode)
    {
        var grouped = ownerMode
            ? appointments.GroupBy(a => a.CustomerId)
            : appointments.GroupBy(a => a.SalonId);

        var result = new List<object>();

        foreach (var group in grouped)
        {
            var latestAppointment = group
                .OrderByDescending(a => a.AppointmentDate)
                .First();

            var thread = await _context.MessageThreads
                .Include(t => t.Messages.OrderByDescending(m => m.CreatedAt))
                .FirstOrDefaultAsync(t =>
                    t.SalonId == latestAppointment.SalonId &&
                    t.CustomerId == latestAppointment.CustomerId &&
                    t.Type == AppointmentThreadType);

            var lastMessage = thread?.Messages.FirstOrDefault();
            result.Add(new
            {
                threadId = thread?.Id,
                type = AppointmentThreadType,
                salonId = latestAppointment.SalonId,
                salonName = latestAppointment.Salon?.Name ?? "",
                customerId = latestAppointment.CustomerId,
                customerName = latestAppointment.Customer?.FullName ?? "",
                serviceName = latestAppointment.Service?.Name ?? "",
                appointmentDate = latestAppointment.AppointmentDate,
                appointmentCount = group.Count(),
                lastMessage = lastMessage?.Content,
                lastMessageAt = lastMessage?.CreatedAt
            });
        }

        return SortThreadDtos(result);
    }

    private async Task<List<object>> BuildInquiryThreadDtos(
        int? salonId = null,
        int? customerId = null)
    {
        var query = _context.MessageThreads
            .Include(t => t.Salon)
            .Include(t => t.Customer)
            .Include(t => t.Messages.OrderByDescending(m => m.CreatedAt))
            .Where(t => t.Type == InquiryThreadType);

        if (salonId.HasValue)
            query = query.Where(t => t.SalonId == salonId.Value);
        if (customerId.HasValue)
            query = query.Where(t => t.CustomerId == customerId.Value);

        var threads = await query
            .OrderByDescending(t => t.UpdatedAt)
            .ToListAsync();

        return threads
            .Select(thread =>
            {
                var lastMessage = thread.Messages.FirstOrDefault();
                return new
                {
                    threadId = thread.Id,
                    type = InquiryThreadType,
                    salonId = thread.SalonId,
                    salonName = thread.Salon?.Name ?? "",
                    customerId = thread.CustomerId,
                    customerName = thread.Customer?.FullName ?? "",
                    serviceName = "Bilgi talebi",
                    appointmentDate = thread.UpdatedAt,
                    appointmentCount = 0,
                    lastMessage = lastMessage?.Content,
                    lastMessageAt = lastMessage?.CreatedAt ?? thread.UpdatedAt
                };
            })
            .Cast<object>()
            .ToList();
    }

    private static List<object> SortThreadDtos(List<object> result)
    {
        return result
            .OrderByDescending(t =>
            {
                var type = t.GetType();
                return (DateTime?)type.GetProperty("lastMessageAt")?.GetValue(t)
                    ?? (DateTime)type.GetProperty("appointmentDate")!.GetValue(t)!;
            })
            .Cast<object>()
            .ToList();
    }

    private Task<bool> HasAppointment(int salonId, int customerId)
    {
        return _context.Appointments.AnyAsync(a =>
            a.SalonId == salonId && a.CustomerId == customerId);
    }

    private async Task<string> ResolveThreadType(
        int salonId,
        int customerId,
        string? requestedType)
    {
        var normalized = NormalizeThreadType(requestedType);
        if (normalized != null) return normalized;

        return await HasAppointment(salonId, customerId)
            ? AppointmentThreadType
            : InquiryThreadType;
    }

    private static string? NormalizeThreadType(string? type)
    {
        if (string.IsNullOrWhiteSpace(type)) return null;

        return type.Trim().ToLowerInvariant() switch
        {
            "appointment" or "randevu" => AppointmentThreadType,
            "inquiry" or "info" or "bilgi" => InquiryThreadType,
            _ => InquiryThreadType
        };
    }

    private async Task<MessageThread> EnsureThread(
        int salonId,
        int customerId,
        string type)
    {
        var thread = await _context.MessageThreads.FirstOrDefaultAsync(t =>
            t.SalonId == salonId && t.CustomerId == customerId && t.Type == type);
        if (thread != null) return thread;

        thread = new MessageThread
        {
            SalonId = salonId,
            CustomerId = customerId,
            Type = type,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _context.MessageThreads.Add(thread);
        await _context.SaveChangesAsync();
        return thread;
    }
}

public class SendMessageRequest
{
    public int SalonId { get; set; }
    public int CustomerId { get; set; }
    public int SenderId { get; set; }
    public string Content { get; set; } = string.Empty;
    public string? Type { get; set; }
}

using System.Net;
using System.Net.Mail;

namespace KuaforApi.Services;

public class EmailService
{
    private readonly IConfiguration _configuration;

    public EmailService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(Get("Smtp__Host")) &&
        !string.IsNullOrWhiteSpace(Get("Smtp__Username")) &&
        !string.IsNullOrWhiteSpace(Get("Smtp__Password"));

    public async Task SendPasswordResetAsync(string toEmail, string fullName, string resetLink)
    {
        if (!IsConfigured)
            throw new InvalidOperationException("SMTP ayarlari tanimli degil.");

        var host = Get("Smtp__Host")!;
        var port = int.TryParse(Get("Smtp__Port"), out var parsedPort) ? parsedPort : 587;
        var username = Get("Smtp__Username")!;
        var password = Get("Smtp__Password")!.Replace(" ", "");
        var from = Get("Smtp__From") ?? username;

        using var client = new SmtpClient(host, port)
        {
            EnableSsl = true,
            Credentials = new NetworkCredential(username, password)
        };

        using var message = new MailMessage(from, toEmail)
        {
            Subject = "Kuafor uygulamasi sifre sifirlama",
            Body = $"Merhaba {fullName},\n\nSifrenizi sifirlamak icin asagidaki baglantiyi acin:\n\n{resetLink}\n\nBu baglanti 1 saat gecerlidir. Talebi siz yapmadiysaniz bu e-postayi yok sayabilirsiniz.\n\nKuafor Randevu Sistemi"
        };

        await client.SendMailAsync(message);
    }

    private string? Get(string key)
    {
        var normalized = key.Replace("__", ":");
        var snake = key
            .Replace("Smtp__", "SMTP_")
            .Replace("__", "_")
            .ToUpperInvariant();

        return Environment.GetEnvironmentVariable(key)?.Trim()
            ?? Environment.GetEnvironmentVariable(normalized)?.Trim()
            ?? Environment.GetEnvironmentVariable(snake)?.Trim()
            ?? _configuration[normalized]?.Trim();
    }
}

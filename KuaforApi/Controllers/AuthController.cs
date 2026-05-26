using KuaforApi.Data;
using KuaforApi.Models;
using KuaforApi.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.EntityFrameworkCore;
using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;

namespace KuaforApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly AuthService _authService;
        private readonly EmailService _emailService;

        public AuthController(AppDbContext context, AuthService authService, EmailService emailService)
        {
            _context = context;
            _authService = authService;
            _emailService = emailService;
        }

        // REGISTER
        [HttpPost("register")]
        public IActionResult Register(RegisterRequest request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.FullName) ||
                    string.IsNullOrWhiteSpace(request.Email) ||
                    string.IsNullOrWhiteSpace(request.Password))
                {
                    return BadRequest(new
                    {
                        message = "Tüm alanları doldurun."
                    });
                }

                var normalizedRole = NormalizeRole(request.Role);

                var user = new User
                {
                    FullName = request.FullName.Trim(),
                    Email = request.Email.Trim().ToLowerInvariant(),
                    Username = request.Username,
                    Role = normalizedRole,
                    AuthProvider = "Password"
                };

                var success = _authService.Register(
                    user,
                    request.Password
                );

                if (!success)
                {
                    return BadRequest(new
                    {
                        message = "Bu e-posta veya kullanıcı adı zaten kayıtlı."
                    });
                }

                var savedUser = _context.Users.FirstOrDefault(u => u.Email == user.Email);
                if (savedUser != null && normalizedRole == "SalonOwner")
                {
                    var salonExists = _context.Salons.Any(s => s.OwnerId == savedUser.Id);
                    if (!salonExists)
                    {
                        _context.Salons.Add(new Salon
                        {
                            Name = string.IsNullOrWhiteSpace(request.SalonName)
                                ? $"{savedUser.FullName} Salonu"
                                : request.SalonName.Trim(),
                            Address = request.SalonAddress ?? "",
                            Description = request.SalonDescription ?? "",
                            OwnerId = savedUser.Id,
                            Latitude = request.SalonLatitude,
                            Longitude = request.SalonLongitude
                        });
                        _context.SaveChanges();
                    }
                }

                return Ok(new
                {
                    message = "Kayıt başarılı."
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    error = ex.Message,
                    detail = ex.InnerException?.Message
                });
            }
        }

        // LOGIN
        [HttpPost("login")]
        public IActionResult Login(LoginRequest request)
        {
            try
            {
                var identifier = string.IsNullOrWhiteSpace(request.Identifier)
                    ? request.Email
                    : request.Identifier;

                var user = _authService.Login(identifier, request.Password);

                if (user == null)
                {
                    return Unauthorized(new
                    {
                        message = "E-posta veya şifre hatalı."
                    });
                }

                var token = _authService.GenerateJwtToken(user);

                return Ok(new
                {
                    token,
                    user = new
                    {
                        user.Id,
                        user.FullName,
                        user.Email,
                        user.Role,
                        user.Specialty,
                        user.ProfileImageUrl,
                        user.Rating
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    error = ex.Message,
                    detail = ex.InnerException?.Message
                });
            }
        }

        [HttpPost("social-login")]
        public IActionResult SocialLogin(SocialLoginRequest request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.Email))
                    return BadRequest(new { message = "Sosyal giriş için e-posta alınamadı." });

                var email = request.Email.Trim().ToLowerInvariant();
                var provider = string.IsNullOrWhiteSpace(request.Provider)
                    ? "Social"
                    : request.Provider.Trim();

                var user = _context.Users.FirstOrDefault(u => u.Email == email);
                if (user == null)
                {
                    user = new User
                    {
                        FullName = string.IsNullOrWhiteSpace(request.FullName)
                            ? email.Split('@')[0]
                            : request.FullName.Trim(),
                        Email = email,
                        Username = GenerateUsername(email),
                        PasswordHash = BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString("N")),
                        Role = "Customer",
                        AuthProvider = provider,
                        ProviderId = request.ProviderId,
                        CreatedAt = DateTime.UtcNow
                    };

                    _context.Users.Add(user);
                    _context.SaveChanges();
                }

                var token = _authService.GenerateJwtToken(user);
                return Ok(new
                {
                    message = $"{provider} ile giriş başarılı.",
                    token,
                    user = new
                    {
                        user.Id,
                        user.FullName,
                        user.Email,
                        user.Role,
                        user.Specialty,
                        user.ProfileImageUrl,
                        user.Rating
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    message = "Sosyal giriş sırasında sunucu hatası oluştu.",
                    error = ex.Message,
                    detail = ex.InnerException?.Message
                });
            }
        }

        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email))
                return BadRequest(new { message = "E-posta zorunludur." });

            var email = request.Email.Trim().ToLowerInvariant();
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null)
                return NotFound(new { message = "Bu e-posta ile kayıtlı kullanıcı bulunamadı." });

            if (!_emailService.IsConfigured)
                return StatusCode(503, new
                {
                    message = "Şifre sıfırlama e-postası gönderilemedi. SMTP ayarları sunucuda tanımlı değil."
                });

            try
            {
                var token = GeneratePasswordResetToken();
                user.PasswordResetTokenHash = HashPasswordResetToken(token);
                user.PasswordResetTokenExpiresAt = DateTime.UtcNow.AddHours(1);
                await _context.SaveChangesAsync();

                var resetLink = Url.ActionLink(
                    nameof(ResetPasswordForm),
                    "Auth",
                    new { email = user.Email, token }
                );

                if (string.IsNullOrWhiteSpace(resetLink))
                    return StatusCode(500, new { message = "Şifre sıfırlama bağlantısı oluşturulamadı." });

                await _emailService.SendPasswordResetAsync(user.Email, user.FullName, resetLink);
                return Ok(new { message = "Şifre sıfırlama e-postası gönderildi." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    message = "E-posta gönderilemedi. SMTP ayarlarını kontrol edin.",
                    error = ex.Message
                });
            }
        }

        [HttpGet("reset-password")]
        public IActionResult ResetPasswordForm([FromQuery] string email, [FromQuery] string token)
        {
            if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(token))
                return Content(BuildResetPasswordHtml("Bağlantı eksik veya geçersiz.", false), "text/html", Encoding.UTF8);

            var safeEmail = HtmlEncoder.Default.Encode(email);
            var safeToken = HtmlEncoder.Default.Encode(token);

            var html = $$"""
                <!doctype html>
                <html lang="tr">
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <title>Şifre Sıfırla</title>
                    <style>
                        body { margin: 0; font-family: Arial, sans-serif; background: #f7f2ee; color: #2d211b; }
                        .wrap { min-height: 100vh; display: grid; place-items: center; padding: 24px; box-sizing: border-box; }
                        form { width: 100%; max-width: 420px; background: #fff; border: 1px solid #eadfd7; border-radius: 16px; padding: 24px; box-sizing: border-box; box-shadow: 0 16px 40px rgba(45, 33, 27, .08); }
                        h1 { margin: 0 0 8px; font-size: 24px; }
                        p { margin: 0 0 20px; color: #746760; line-height: 1.45; }
                        label { display: block; margin-bottom: 8px; font-weight: 700; font-size: 14px; }
                        input { width: 100%; box-sizing: border-box; border: 1px solid #d8cbc1; border-radius: 10px; padding: 13px 12px; font-size: 16px; margin-bottom: 14px; }
                        button { width: 100%; border: 0; border-radius: 10px; padding: 14px; font-size: 16px; font-weight: 700; color: #fff; background: #7a4d39; cursor: pointer; }
                    </style>
                </head>
                <body>
                    <div class="wrap">
                        <form method="post" action="/api/Auth/reset-password">
                            <h1>Şifre Sıfırla</h1>
                            <p>Yeni şifreniz en az 6 karakter olmalı.</p>
                            <input type="hidden" name="email" value="{{safeEmail}}">
                            <input type="hidden" name="token" value="{{safeToken}}">
                            <label for="newPassword">Yeni şifre</label>
                            <input id="newPassword" name="newPassword" type="password" minlength="6" required autocomplete="new-password">
                            <button type="submit">Şifreyi Güncelle</button>
                        </form>
                    </div>
                </body>
                </html>
                """;

            return Content(html, "text/html", Encoding.UTF8);
        }

        [HttpPost("reset-password")]
        [Consumes("application/x-www-form-urlencoded")]
        public async Task<IActionResult> ResetPassword([FromForm] ResetPasswordRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email) ||
                string.IsNullOrWhiteSpace(request.Token) ||
                string.IsNullOrWhiteSpace(request.NewPassword))
            {
                return Content(BuildResetPasswordHtml("Tüm alanlar zorunludur.", false), "text/html", Encoding.UTF8);
            }

            if (request.NewPassword.Length < 6)
                return Content(BuildResetPasswordHtml("Yeni şifre en az 6 karakter olmalıdır.", false), "text/html", Encoding.UTF8);

            var email = request.Email.Trim().ToLowerInvariant();
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null ||
                string.IsNullOrWhiteSpace(user.PasswordResetTokenHash) ||
                user.PasswordResetTokenExpiresAt == null ||
                user.PasswordResetTokenExpiresAt < DateTime.UtcNow)
            {
                return Content(BuildResetPasswordHtml("Şifre sıfırlama bağlantısı geçersiz veya süresi dolmuş.", false), "text/html", Encoding.UTF8);
            }

            var tokenHash = HashPasswordResetToken(request.Token);
            if (!CryptographicOperations.FixedTimeEquals(
                    Encoding.UTF8.GetBytes(tokenHash),
                    Encoding.UTF8.GetBytes(user.PasswordResetTokenHash)))
            {
                return Content(BuildResetPasswordHtml("Şifre sıfırlama bağlantısı geçersiz veya süresi dolmuş.", false), "text/html", Encoding.UTF8);
            }

            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
            user.PasswordResetTokenHash = null;
            user.PasswordResetTokenExpiresAt = null;
            await _context.SaveChangesAsync();

            return Content(BuildResetPasswordHtml("Şifreniz güncellendi. Uygulamadan yeni şifrenizle giriş yapabilirsiniz.", true), "text/html", Encoding.UTF8);
        }

        private string GenerateUsername(string email)
        {
            var prefix = email.Split('@')[0]
                .ToLowerInvariant()
                .Replace(".", "")
                .Replace("_", "")
                .Replace("-", "");

            for (var i = 0; i < 10; i++)
            {
                var candidate = $"{prefix}{Random.Shared.Next(1000, 9999)}";
                if (!_context.Users.Any(u => u.Username == candidate))
                    return candidate;
            }

            return $"user{Guid.NewGuid():N}"[..16];
        }

        private static string NormalizeRole(string? role)
        {
            return role?.Trim() switch
            {
                "Müşteri" => "Customer",
                "Customer" => "Customer",
                "Kuaför" => "Hairdresser",
                "Hairdresser" => "Hairdresser",
                "Salon Sahibi" => "SalonOwner",
                "SalonOwner" => "SalonOwner",
                _ => "Customer"
            };
        }

        private static string GeneratePasswordResetToken()
        {
            return WebEncoders.Base64UrlEncode(RandomNumberGenerator.GetBytes(32));
        }

        private static string HashPasswordResetToken(string token)
        {
            var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
            return Convert.ToBase64String(bytes);
        }

        private static string BuildResetPasswordHtml(string message, bool isSuccess)
        {
            var color = isSuccess ? "#217a48" : "#b3261e";
            var safeMessage = HtmlEncoder.Default.Encode(message);

            return $$"""
                <!doctype html>
                <html lang="tr">
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <title>Şifre Sıfırlama</title>
                    <style>
                        body { margin: 0; font-family: Arial, sans-serif; background: #f7f2ee; color: #2d211b; }
                        .wrap { min-height: 100vh; display: grid; place-items: center; padding: 24px; box-sizing: border-box; }
                        .box { width: 100%; max-width: 420px; background: #fff; border: 1px solid #eadfd7; border-radius: 16px; padding: 24px; box-sizing: border-box; text-align: center; box-shadow: 0 16px 40px rgba(45, 33, 27, .08); }
                        h1 { margin: 0 0 10px; font-size: 24px; }
                        p { margin: 0; color: {{color}}; line-height: 1.45; font-weight: 700; }
                    </style>
                </head>
                <body>
                    <div class="wrap">
                        <div class="box">
                            <h1>Şifre Sıfırlama</h1>
                            <p>{{safeMessage}}</p>
                        </div>
                    </div>
                </body>
                </html>
                """;
        }
    }

    public class RegisterRequest
    {
        public string FullName { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public string? Username { get; set; }

        public string Password { get; set; } = string.Empty;

        public string? Role { get; set; }

        public string? SalonName { get; set; }

        public string? SalonAddress { get; set; }

        public string? SalonDescription { get; set; }

        public double? SalonLatitude { get; set; }

        public double? SalonLongitude { get; set; }
    }

    public class LoginRequest
    {
        public string? Identifier { get; set; }

        public string Email { get; set; } = string.Empty;

        public string Password { get; set; } = string.Empty;
    }

    public class SocialLoginRequest
    {
        public string Provider { get; set; } = string.Empty;
        public string ProviderId { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
    }

    public class ForgotPasswordRequest
    {
        public string Email { get; set; } = string.Empty;
    }

    public class ResetPasswordRequest
    {
        public string Email { get; set; } = string.Empty;
        public string Token { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }
}

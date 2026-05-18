using KuaforApi.Data;
using KuaforApi.Models;
using KuaforApi.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

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
                            Description = "",
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
                return Ok(new { message = "SMTP ayarı tanımlı değil. Demo modunda sıfırlama talebi alındı." });

            try
            {
                await _emailService.SendPasswordResetAsync(user.Email, user.FullName);
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
}

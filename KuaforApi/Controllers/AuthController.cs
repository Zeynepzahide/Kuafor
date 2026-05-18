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

        public AuthController(AppDbContext context, AuthService authService)
        {
            _context = context;
            _authService = authService;
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

                var normalizedRole =
                    string.IsNullOrWhiteSpace(request.Role)
                    ? "Customer"
                    : request.Role.Trim();

                var user = new User
                {
                    FullName = request.FullName.Trim(),
                    Email = request.Email.Trim(),
                    Role = normalizedRole
                };

                var success = _authService.Register(
                    user,
                    request.Password
                );

                if (!success)
                {
                    return BadRequest(new
                    {
                        message = "Bu e-posta zaten kayıtlı."
                    });
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
                var user = _authService.Login(
                    request.Email,
                    request.Password
                );

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
    }

    public class RegisterRequest
    {
        public string FullName { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public string Password { get; set; } = string.Empty;

        public string? Role { get; set; }
    }

    public class LoginRequest
    {
        public string Email { get; set; } = string.Empty;

        public string Password { get; set; } = string.Empty;
    }
}
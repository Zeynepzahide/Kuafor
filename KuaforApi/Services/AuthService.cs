using KuaforApi.Models;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using KuaforApi.Data;
using BCrypt.Net;
using Microsoft.EntityFrameworkCore;

namespace KuaforApi.Services
{
    public class AuthService
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;

        public AuthService(AppDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
        }

        // Kullanıcı kaydı
        public bool Register(User user, string password)
        {
            user.Email = user.Email.Trim().ToLowerInvariant();
            user.Username = string.IsNullOrWhiteSpace(user.Username)
                ? GenerateUsername(user.Email)
                : user.Username.Trim().ToLowerInvariant();
            user.CreatedAt = DateTime.UtcNow;

            // Aynı email varsa kaydetme
            if (_context.Users.Any(u => u.Email == user.Email ||
                                        (!string.IsNullOrWhiteSpace(user.Username) && u.Username == user.Username)))
                return false;

            // Şifreyi hashle
            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);

            // Kaydet
            try
            {
                _context.Users.Add(user);
                _context.SaveChanges();
            }
            catch (DbUpdateException)
            {
                return false;
            }

            return true;
        }

        // Giriş yapma
        public User? Login(string identifier, string password)
        {
            var normalized = identifier.Trim().ToLowerInvariant();
            var user = _context.Users
                .FirstOrDefault(u => u.Email == normalized ||
                                     u.Username == normalized);

            if (user == null)
                return null;

            bool isValid = BCrypt.Net.BCrypt.Verify(
                password,
                user.PasswordHash
            );

            return isValid ? user : null;
        }

        // JWT üret
        public string GenerateJwtToken(User user)
        {
            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.Email),
                new Claim(ClaimTypes.Role, user.Role)
            };

            var jwtKey =
                Environment.GetEnvironmentVariable("Jwt__Key")
                ?? _configuration["Jwt:Key"];

            if (string.IsNullOrWhiteSpace(jwtKey))
            {
                jwtKey = "this_is_a_very_strong_secret_key_1234567890";
            }

            var key = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwtKey)
            );

            var creds = new SigningCredentials(
                key,
                SecurityAlgorithms.HmacSha256
            );

            var token = new JwtSecurityToken(
                issuer: "KuaforApi",
                audience: "KuaforApiClient",
                claims: claims,
                expires: DateTime.Now.AddHours(3),
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
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
    }
}

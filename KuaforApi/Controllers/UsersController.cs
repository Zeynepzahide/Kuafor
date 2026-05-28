using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using KuaforApi.Data;
using BCrypt.Net;

namespace KuaforApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class UsersController : ControllerBase
    {
        private readonly AppDbContext _context;
        public UsersController(AppDbContext context)
        {
            _context = context;
        }

        [Authorize]
        [HttpGet("me")]
        public IActionResult GetProfile()
        {
            var email = User?.Identity?.Name;
            if (string.IsNullOrEmpty(email))
                return Unauthorized(new { message = "Token geçersiz." });

            var user = _context.Users.FirstOrDefault(u => u.Email == email);
            if (user == null)
                return NotFound(new { message = "Kullanıcı bulunamadı." });

            var baseUrl = $"{Request.Scheme}://{Request.Host}";
            var imageUrl = user.ProfileImageUrl;
            if (!string.IsNullOrEmpty(imageUrl) && imageUrl.StartsWith("/"))
                imageUrl = $"{baseUrl}{imageUrl}";

            return Ok(new
            {
                id = user.Id,
                fullName = user.FullName,
                email = user.Email,
                role = user.Role,
                profileImageUrl = imageUrl ?? ""
            });
        }

        [Authorize]
        [HttpPut("update")]
        public IActionResult UpdateProfile([FromBody] UpdateUserRequest request)
        {
            var email = User?.Identity?.Name;
            if (string.IsNullOrEmpty(email))
                return Unauthorized(new { message = "Token geçersiz." });

            var user = _context.Users.FirstOrDefault(u => u.Email == email);
            if (user == null)
                return NotFound(new { message = "Kullanıcı bulunamadı." });

            if (!string.IsNullOrWhiteSpace(request.FullName))
                user.FullName = request.FullName.Trim();

            if (!string.IsNullOrWhiteSpace(request.Password))
                user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);

            _context.SaveChanges();

            var baseUrl = $"{Request.Scheme}://{Request.Host}";
            var imageUrl = user.ProfileImageUrl;
            if (!string.IsNullOrEmpty(imageUrl) && imageUrl.StartsWith("/"))
                imageUrl = $"{baseUrl}{imageUrl}";

            return Ok(new
            {
                message = "Profil güncellendi.",
                user = new
                {
                    id = user.Id,
                    fullName = user.FullName,
                    email = user.Email,
                    role = user.Role,
                    profileImageUrl = imageUrl ?? ""
                }
            });
        }

        [Authorize]
        [HttpPost("upload-photo")]
        public async Task<IActionResult> UploadPhoto(IFormFile file)
        {
            var email = User?.Identity?.Name;
            if (string.IsNullOrEmpty(email))
                return Unauthorized(new { message = "Token geçersiz." });

            var user = _context.Users.FirstOrDefault(u => u.Email == email);
            if (user == null)
                return NotFound(new { message = "Kullanıcı bulunamadı." });

            if (file == null || file.Length == 0)
                return BadRequest(new { message = "Dosya boş." });

            var allowed = new[] { "image/jpeg", "image/png", "image/webp", "image/jpg" };
            if (!allowed.Contains(file.ContentType.ToLower()))
                return BadRequest(new { message = "Sadece JPEG, PNG veya WebP yükleyebilirsiniz." });

            if (file.Length > 5 * 1024 * 1024)
                return BadRequest(new { message = "Dosya 5MB'dan büyük olamaz." });

            await using var memory = new MemoryStream();
            await file.CopyToAsync(memory);

            user.ProfileImageData = memory.ToArray();
            user.ProfileImageContentType = file.ContentType.ToLower();
            user.ProfileImageUpdatedAt = DateTime.UtcNow;
            user.ProfileImageUrl = $"/api/Users/profile-photo/{user.Id}?v={DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
            _context.SaveChanges();

            var baseUrl = $"{Request.Scheme}://{Request.Host}";
            var imageUrl = $"{baseUrl}{user.ProfileImageUrl}";

            return Ok(new
            {
                message = "Fotoğraf yüklendi.",
                profileImageUrl = imageUrl
            });
        }

        [HttpGet("profile-photo/{id:int}")]
        public IActionResult GetProfilePhoto(int id)
        {
            var user = _context.Users.FirstOrDefault(u => u.Id == id);
            if (user?.ProfileImageData == null || user.ProfileImageData.Length == 0)
                return NotFound();

            return File(
                user.ProfileImageData,
                string.IsNullOrWhiteSpace(user.ProfileImageContentType)
                    ? "image/jpeg"
                    : user.ProfileImageContentType
            );
        }
    }

    public class UpdateUserRequest
    {
        public string? FullName { get; set; }
        public string? Password { get; set; }
    }
}

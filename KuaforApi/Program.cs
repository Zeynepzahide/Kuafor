using KuaforApi.Data;
using KuaforApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

var connectionString =
    Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")
    ?? builder.Configuration.GetConnectionString("DefaultConnection");

if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        "Database connection string is missing. Set ConnectionStrings__DefaultConnection on Render or in local user secrets.");
}

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(connectionString));

builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<EmailService>();

var jwtKey =
    Environment.GetEnvironmentVariable("Jwt__Key")
    ?? builder.Configuration["Jwt:Key"];

if (string.IsNullOrWhiteSpace(jwtKey))
{
    jwtKey = "this_is_a_very_strong_secret_key_1234567890";
}
var key = Encoding.UTF8.GetBytes(jwtKey);

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(key),
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidIssuer = "KuaforApi",
        ValidAudience = "KuaforApiClient",
        ClockSkew = TimeSpan.Zero
    };
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Kuafor API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "Lütfen JWT token'ınızı 'Bearer <token>' formatında girin",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

var port = Environment.GetEnvironmentVariable("PORT") ?? "5069";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

var app = builder.Build();
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        db.Database.Migrate();
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "EF migration failed. Continuing with compatibility schema repair.");
    }

    try
    {
        RepairRenderSchema(db);
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "Render schema repair failed.");
    }
}

app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(new
        {
            message = "Sunucu tarafında beklenmeyen bir hata oluştu.",
            traceId = context.TraceIdentifier
        });
    });
});

app.UseSwagger();
app.UseSwaggerUI();

// ✅ CORS en üstte
app.UseCors("AllowAll");

// ✅ HttpsRedirection CORS'tan sonra
app.UseHttpsRedirection();

var wwwrootPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
Directory.CreateDirectory(wwwrootPath);
Directory.CreateDirectory(Path.Combine(wwwrootPath, "uploads", "profiles"));
Directory.CreateDirectory(Path.Combine(wwwrootPath, "uploads", "posts"));

app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(wwwrootPath),
    RequestPath = ""
});

app.UseAuthentication();
app.UseAuthorization();
app.MapGet("/health", (EmailService emailService) => Results.Ok(new
{
    status = "ok",
    service = "KuaforApi",
    smtpConfigured = emailService.IsConfigured,
    timestamp = DateTime.UtcNow
}));
app.MapControllers();
app.Run();

static void RepairRenderSchema(AppDbContext db)
{
    db.Database.ExecuteSqlRaw("""
        ALTER TABLE IF EXISTS "Users"
            ADD COLUMN IF NOT EXISTS "Username" text,
            ADD COLUMN IF NOT EXISTS "AuthProvider" text,
            ADD COLUMN IF NOT EXISTS "ProviderId" text,
            ADD COLUMN IF NOT EXISTS "PasswordResetTokenHash" text,
            ADD COLUMN IF NOT EXISTS "PasswordResetTokenExpiresAt" timestamp with time zone NULL,
            ADD COLUMN IF NOT EXISTS "CreatedAt" timestamp with time zone NOT NULL DEFAULT NOW();

        ALTER TABLE IF EXISTS "Campaigns"
            ADD COLUMN IF NOT EXISTS "Code" text,
            ADD COLUMN IF NOT EXISTS "StartDate" timestamp with time zone NOT NULL DEFAULT NOW(),
            ADD COLUMN IF NOT EXISTS "EndDate" timestamp with time zone NULL;

        CREATE TABLE IF NOT EXISTS "StylistAvailabilities" (
            "Id" integer GENERATED BY DEFAULT AS IDENTITY,
            "StylistId" integer NOT NULL,
            "DayOfWeek" integer NOT NULL,
            "IsOpen" boolean NOT NULL,
            "OpenTime" interval NOT NULL,
            "CloseTime" interval NOT NULL,
            CONSTRAINT "PK_StylistAvailabilities" PRIMARY KEY ("Id"),
            CONSTRAINT "FK_StylistAvailabilities_Users_StylistId"
                FOREIGN KEY ("StylistId") REFERENCES "Users" ("Id") ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS "IX_Users_Username" ON "Users" ("Username");
        CREATE INDEX IF NOT EXISTS "IX_StylistAvailabilities_StylistId_DayOfWeek"
            ON "StylistAvailabilities" ("StylistId", "DayOfWeek");
    """);
}

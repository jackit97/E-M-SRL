using System.Security.Claims;
using System.Text;
using EmCasa.Api.Contracts;
using EmCasa.Api.Data;
using EmCasa.Api.Models;
using EmCasa.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

var connectionString = ResolveConnectionString(builder.Configuration);
var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
dataSourceBuilder.MapEnum<UserRole>("emcasa.user_role");
dataSourceBuilder.MapEnum<HouseRequestStatus>("emcasa.request_status");
var dataSource = dataSourceBuilder.Build();

builder.Services.AddSingleton(dataSource);
builder.Services.AddDbContext<AppDbContext>(options => options.UseNpgsql(dataSource).UseSnakeCaseNamingConvention());
builder.Services.AddScoped<IPasswordHasher<AppUser>, PasswordHasher<AppUser>>();
builder.Services.AddScoped<JwtTokenService>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("Frontend", policy =>
    {
        policy.WithOrigins("http://localhost:5173")
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var jwtSection = builder.Configuration.GetSection("Jwt");
var jwtKey = jwtSection["Key"] ?? throw new InvalidOperationException("Missing Jwt:Key configuration.");
var jwtIssuer = jwtSection["Issuer"] ?? "EmCasa.Api";
var jwtAudience = jwtSection["Audience"] ?? "EmCasa.Web";

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy => policy.RequireRole(UserRole.Admin.ToString()));
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "E&M Casa API", Version = "v1" });
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Insert JWT token: Bearer {token}"
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
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

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    var passwordHasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher<AppUser>>();
    try
    {
        if (!db.Users.Any(user => user.Role == UserRole.Admin))
        {
            var adminEmail = builder.Configuration["SeedAdmin:Email"] ?? "admin@emcasa.local";
            var adminPassword = builder.Configuration["SeedAdmin:Password"] ?? "Admin123!";

            var admin = new AppUser
            {
                FullName = "Admin E&M",
                Email = adminEmail.Trim().ToLowerInvariant(),
                Role = UserRole.Admin,
                PrivacyConsent = true,
                SubscriptionActive = true,
                SubscriptionExpiresAtUtc = DateTime.UtcNow.AddYears(10)
            };
            admin.PasswordHash = passwordHasher.HashPassword(admin, adminPassword);

            db.Users.Add(admin);
            db.SaveChanges();
        }
    }
    catch (PostgresException ex) when (ex.SqlState is "42P01" or "3F000" or "42704")
    {
        throw new InvalidOperationException(
            "Database schema non inizializzato. Esegui gli script in database/sql (001, 002, 003) prima di avviare l'API.",
            ex);
    }
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("Frontend");
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api/health", () => Results.Ok(new { status = "ok" }));

app.MapGet("/api/public/site-content", () => Results.Ok(new
{
    home = "Trova o realizza la tua casa personalizzata in Italia.",
    comeFunziona = "Registrati, attiva abbonamento, crea richiesta e segui gli aggiornamenti.",
    abbonamento = "14,99 € / anno",
    chiSiamo = "E&M Srl - supporto completo per ricerca e sviluppo immobiliare.",
    contatti = new
    {
        telefono = "3282054849",
        email = "emsrlimpresa@gmail.com",
        sede = "Lavezzola, Via Adige 1, Comune di Conselice"
    }
}));

app.MapPost("/api/auth/register", async (
    RegisterRequest request,
    AppDbContext db,
    IPasswordHasher<AppUser> passwordHasher,
    JwtTokenService jwtTokenService) =>
{
    var email = request.Email.Trim().ToLowerInvariant();

    if (string.IsNullOrWhiteSpace(request.FullName) || string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(request.Password))
    {
        return Results.BadRequest(new { message = "FullName, Email e Password sono obbligatori." });
    }

    if (request.Password.Length < 8)
    {
        return Results.BadRequest(new { message = "La password deve avere almeno 8 caratteri." });
    }

    var emailExists = await db.Users.AnyAsync(user => user.Email == email);
    if (emailExists)
    {
        return Results.Conflict(new { message = "Email gia registrata." });
    }

    var user = new AppUser
    {
        FullName = request.FullName.Trim(),
        Email = email,
        PrivacyConsent = request.PrivacyConsent,
        Role = UserRole.Customer
    };
    user.PasswordHash = passwordHasher.HashPassword(user, request.Password);

    db.Users.Add(user);
    await db.SaveChangesAsync();

    var token = jwtTokenService.GenerateToken(user);
    return Results.Ok(new AuthResponse(user.Id, user.FullName, user.Email, user.Role.ToString(), token));
});

app.MapPost("/api/auth/login", async (
    LoginRequest request,
    AppDbContext db,
    IPasswordHasher<AppUser> passwordHasher,
    JwtTokenService jwtTokenService) =>
{
    var email = request.Email.Trim().ToLowerInvariant();
    var user = await db.Users.FirstOrDefaultAsync(item => item.Email == email);
    if (user is null)
    {
        return Results.Unauthorized();
    }

    var verificationResult = passwordHasher.VerifyHashedPassword(user, user.PasswordHash, request.Password);
    if (verificationResult == PasswordVerificationResult.Failed)
    {
        return Results.Unauthorized();
    }

    var token = jwtTokenService.GenerateToken(user);
    return Results.Ok(new AuthResponse(user.Id, user.FullName, user.Email, user.Role.ToString(), token));
});

app.MapGet("/api/me", async (ClaimsPrincipal principal, AppDbContext db) =>
{
    var userId = GetCurrentUserId(principal);
    if (userId is null)
    {
        return Results.Unauthorized();
    }

    var user = await db.Users
        .AsNoTracking()
        .FirstOrDefaultAsync(item => item.Id == userId.Value);

    return user is null
        ? Results.NotFound()
        : Results.Ok(new
        {
            user.Id,
            user.FullName,
            user.Email,
            Role = user.Role.ToString(),
            user.SubscriptionActive,
            user.SubscriptionExpiresAtUtc
        });
}).RequireAuthorization();

app.MapPost("/api/subscription/activate", async (ClaimsPrincipal principal, AppDbContext db) =>
{
    var userId = GetCurrentUserId(principal);
    if (userId is null)
    {
        return Results.Unauthorized();
    }

    var user = await db.Users.FirstOrDefaultAsync(item => item.Id == userId.Value);
    if (user is null)
    {
        return Results.NotFound();
    }

    user.SubscriptionActive = true;
    user.SubscriptionExpiresAtUtc = DateTime.UtcNow.AddYears(1);
    await db.SaveChangesAsync();

    return Results.Ok(new
    {
        message = "Abbonamento attivato.",
        user.SubscriptionActive,
        user.SubscriptionExpiresAtUtc
    });
}).RequireAuthorization();

app.MapPost("/api/house-requests", async (CreateHouseRequestDto request, ClaimsPrincipal principal, AppDbContext db) =>
{
    var userId = GetCurrentUserId(principal);
    if (userId is null)
    {
        return Results.Unauthorized();
    }

    var user = await db.Users.FirstOrDefaultAsync(item => item.Id == userId.Value);
    if (user is null)
    {
        return Results.NotFound();
    }

    if (!user.SubscriptionActive || user.SubscriptionExpiresAtUtc is null || user.SubscriptionExpiresAtUtc < DateTime.UtcNow)
    {
        return Results.BadRequest(new { message = "Abbonamento non attivo." });
    }

    var houseRequest = new HouseRequest
    {
        UserId = user.Id,
        Region = request.Region,
        Province = request.Province,
        CityOrArea = request.CityOrArea,
        BudgetMin = request.BudgetMin,
        BudgetMax = request.BudgetMax,
        PropertyType = request.PropertyType,
        PropertyCondition = request.PropertyCondition,
        SquareMeters = request.SquareMeters,
        Bedrooms = request.Bedrooms,
        Bathrooms = request.Bathrooms,
        HasGarden = request.HasGarden,
        HasGarage = request.HasGarage,
        HasTerrace = request.HasTerrace,
        HasPool = request.HasPool,
        HasCellar = request.HasCellar,
        EnergyClass = request.EnergyClass,
        Style = request.Style,
        FinishingLevel = request.FinishingLevel,
        DesiredTimeline = request.DesiredTimeline,
        Notes = request.Notes,
        AttachmentUrl = request.AttachmentUrl,
        Status = HouseRequestStatus.Submitted
    };

    db.HouseRequests.Add(houseRequest);
    await db.SaveChangesAsync();

    return Results.Created($"/api/house-requests/{houseRequest.Id}", houseRequest);
}).RequireAuthorization();

app.MapGet("/api/house-requests/me", async (ClaimsPrincipal principal, AppDbContext db) =>
{
    var userId = GetCurrentUserId(principal);
    if (userId is null)
    {
        return Results.Unauthorized();
    }

    var requests = await db.HouseRequests
        .AsNoTracking()
        .Where(item => item.UserId == userId.Value)
        .OrderByDescending(item => item.CreatedAt)
        .ToListAsync();

    return Results.Ok(requests);
}).RequireAuthorization();

var adminGroup = app.MapGroup("/api/admin")
    .RequireAuthorization("AdminOnly");

adminGroup.MapGet("/users", async (AppDbContext db) =>
{
    var users = await db.Users
        .AsNoTracking()
        .OrderByDescending(item => item.CreatedAt)
        .Select(item => new
        {
            item.Id,
            item.FullName,
            item.Email,
            Role = item.Role.ToString(),
            item.SubscriptionActive,
            item.SubscriptionExpiresAtUtc,
            item.CreatedAt
        })
        .ToListAsync();

    return Results.Ok(users);
});

adminGroup.MapGet("/house-requests", async (AppDbContext db) =>
{
    var requests = await db.HouseRequests
        .AsNoTracking()
        .Include(item => item.User)
        .OrderByDescending(item => item.CreatedAt)
        .Select(item => new
        {
            item.Id,
            item.UserId,
            customerName = item.User.FullName,
            customerEmail = item.User.Email,
            item.Region,
            item.Province,
            item.CityOrArea,
            item.BudgetMin,
            item.BudgetMax,
            item.PropertyType,
            item.Status,
            item.CreatedAt,
            item.UpdatedAt
        })
        .ToListAsync();

    return Results.Ok(requests);
});

adminGroup.MapPatch("/house-requests/{id:guid}/status", async (Guid id, UpdateHouseRequestStatusDto request, AppDbContext db) =>
{
    if (!Enum.TryParse<HouseRequestStatus>(request.Status, true, out var parsedStatus))
    {
        return Results.BadRequest(new
        {
            message = "Stato non valido.",
            validStatuses = Enum.GetNames<HouseRequestStatus>()
        });
    }

    var houseRequest = await db.HouseRequests.FirstOrDefaultAsync(item => item.Id == id);
    if (houseRequest is null)
    {
        return Results.NotFound();
    }

    houseRequest.Status = parsedStatus;
    houseRequest.UpdatedAt = DateTime.UtcNow;
    await db.SaveChangesAsync();

    return Results.Ok(houseRequest);
});

app.Run();

static Guid? GetCurrentUserId(ClaimsPrincipal principal)
{
    var value = principal.FindFirstValue(ClaimTypes.NameIdentifier);
    return Guid.TryParse(value, out var userId) ? userId : null;
}

static string ResolveConnectionString(IConfiguration configuration)
{
    var databaseUrl = configuration["DATABASE_URL"];
    if (!string.IsNullOrWhiteSpace(databaseUrl))
    {
        var resolved = databaseUrl.Contains("Host=", StringComparison.OrdinalIgnoreCase)
            ? databaseUrl
            : ConvertDatabaseUrlToNpgsql(databaseUrl);

        return EnsureSearchPath(resolved);
    }

    var configuredConnection = configuration.GetConnectionString("DefaultConnection");
    if (!string.IsNullOrWhiteSpace(configuredConnection))
    {
        return EnsureSearchPath(configuredConnection);
    }

    throw new InvalidOperationException("Missing database connection. Set ConnectionStrings:DefaultConnection or DATABASE_URL.");
}

static string EnsureSearchPath(string connectionString)
{
    var builder = new NpgsqlConnectionStringBuilder(connectionString);
    if (string.IsNullOrWhiteSpace(builder.SearchPath))
    {
        builder.SearchPath = "emcasa,public";
    }

    return builder.ConnectionString;
}

static string ConvertDatabaseUrlToNpgsql(string databaseUrl)
{
    if (!Uri.TryCreate(databaseUrl, UriKind.Absolute, out var uri))
    {
        throw new InvalidOperationException("DATABASE_URL is not a valid absolute URI.");
    }

    if (uri.Scheme is not ("postgres" or "postgresql"))
    {
        throw new InvalidOperationException("DATABASE_URL must use postgres/postgresql scheme.");
    }

    var userInfo = uri.UserInfo.Split(':', 2);
    if (userInfo.Length != 2)
    {
        throw new InvalidOperationException("DATABASE_URL must include username and password.");
    }

    var database = uri.AbsolutePath.Trim('/');
    if (string.IsNullOrWhiteSpace(database))
    {
        throw new InvalidOperationException("DATABASE_URL must include database name in path.");
    }

    var csBuilder = new NpgsqlConnectionStringBuilder
    {
        Host = uri.Host,
        Port = uri.Port > 0 ? uri.Port : 5432,
        Database = database,
        Username = Uri.UnescapeDataString(userInfo[0]),
        Password = Uri.UnescapeDataString(userInfo[1]),
        SslMode = SslMode.Require
    };

    if (!string.IsNullOrWhiteSpace(uri.Query))
    {
        var queryParams = uri.Query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries);
        foreach (var queryParam in queryParams)
        {
            var keyValue = queryParam.Split('=', 2);
            var key = Uri.UnescapeDataString(keyValue[0]).ToLowerInvariant();
            var value = keyValue.Length > 1 ? Uri.UnescapeDataString(keyValue[1]) : string.Empty;

            if (key == "sslmode" && Enum.TryParse<SslMode>(value, true, out var sslMode))
            {
                csBuilder.SslMode = sslMode;
            }

        }
    }

    return csBuilder.ConnectionString;
}

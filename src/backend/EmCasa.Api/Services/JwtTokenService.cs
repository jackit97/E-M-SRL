using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using EmCasa.Api.Models;
using Microsoft.IdentityModel.Tokens;

namespace EmCasa.Api.Services;

public class JwtTokenService(IConfiguration configuration)
{
    public string GenerateToken(AppUser user)
    {
        var key = configuration["Jwt:Key"] ?? throw new InvalidOperationException("Missing Jwt:Key");
        var issuer = configuration["Jwt:Issuer"] ?? "EmCasa.Api";
        var audience = configuration["Jwt:Audience"] ?? "EmCasa.Web";
        var expiresHours = int.TryParse(configuration["Jwt:ExpiresHours"], out var parsedHours) ? parsedHours : 24;

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name, user.FullName),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Role, user.Role.ToString())
        };

        var signingCredentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer,
            audience,
            claims,
            expires: DateTime.UtcNow.AddHours(expiresHours),
            signingCredentials: signingCredentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}

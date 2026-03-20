namespace EmCasa.Api.Contracts;

public record RegisterRequest(
    string FullName,
    string Email,
    string Password,
    bool PrivacyConsent);

public record LoginRequest(
    string Email,
    string Password);

public record AuthResponse(
    Guid UserId,
    string FullName,
    string Email,
    string Role,
    string Token);

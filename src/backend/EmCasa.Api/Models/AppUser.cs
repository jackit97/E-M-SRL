namespace EmCasa.Api.Models;

public class AppUser
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public bool PrivacyConsent { get; set; }
    public UserRole Role { get; set; } = UserRole.Customer;
    public bool SubscriptionActive { get; set; }
    public DateTime? SubscriptionExpiresAtUtc { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<HouseRequest> HouseRequests { get; set; } = new List<HouseRequest>();
}

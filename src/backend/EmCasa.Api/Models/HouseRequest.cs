namespace EmCasa.Api.Models;

public class HouseRequest
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = default!;

    public string Region { get; set; } = string.Empty;
    public string Province { get; set; } = string.Empty;
    public string CityOrArea { get; set; } = string.Empty;

    public decimal BudgetMin { get; set; }
    public decimal BudgetMax { get; set; }

    public string PropertyType { get; set; } = string.Empty;
    public string PropertyCondition { get; set; } = string.Empty;

    public int SquareMeters { get; set; }
    public int Bedrooms { get; set; }
    public int Bathrooms { get; set; }

    public bool HasGarden { get; set; }
    public bool HasGarage { get; set; }
    public bool HasTerrace { get; set; }
    public bool HasPool { get; set; }
    public bool HasCellar { get; set; }

    public string EnergyClass { get; set; } = string.Empty;
    public string Style { get; set; } = string.Empty;
    public string FinishingLevel { get; set; } = string.Empty;

    public string DesiredTimeline { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
    public string? AttachmentUrl { get; set; }

    public HouseRequestStatus Status { get; set; } = HouseRequestStatus.Submitted;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

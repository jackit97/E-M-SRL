namespace EmCasa.Api.Contracts;

public record CreateHouseRequestDto(
    string Region,
    string Province,
    string CityOrArea,
    decimal BudgetMin,
    decimal BudgetMax,
    string PropertyType,
    string PropertyCondition,
    int SquareMeters,
    int Bedrooms,
    int Bathrooms,
    bool HasGarden,
    bool HasGarage,
    bool HasTerrace,
    bool HasPool,
    bool HasCellar,
    string EnergyClass,
    string Style,
    string FinishingLevel,
    string DesiredTimeline,
    string Notes,
    string? AttachmentUrl);

public record UpdateHouseRequestStatusDto(string Status);

namespace PondyConnect.Application.Features.Users;

/// <summary>
/// Saves a new address for the authenticated user.
/// </summary>
public sealed record SaveUserAddressCommand(
    string? DoorFlat,
    string? Landmark,
    string Tag,
    double Latitude,
    double Longitude,
    string FormattedAddress);

/// <summary>
/// The saved address returned to the caller.
/// </summary>
public sealed record UserAddressResponse(
    Guid Id,
    string? DoorFlat,
    string? Landmark,
    string Tag,
    double Latitude,
    double Longitude,
    string FormattedAddress);

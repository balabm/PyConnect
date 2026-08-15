namespace PondyConnect.Application.Features.Auth;

/// <summary>
/// Result of a social login attempt. When <see cref="NeedsPhone"/> is true the
/// caller must collect and verify a phone number before the account is created.
/// </summary>
public sealed record SocialAuthResponse(
    string? AccessToken,
    bool NeedsPhone,
    string? Name,
    string? Phone,
    string? Role,
    bool IsProMember = false,
    string? Message = null);

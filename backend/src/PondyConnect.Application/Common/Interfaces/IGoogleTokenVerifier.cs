namespace PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Result of verifying a Google ID token.
/// </summary>
public sealed record GoogleUserInfo(
    string GoogleId,
    string Email,
    bool IsEmailVerified,
    string? Name,
    string? PictureUrl);

/// <summary>
/// Verifies a Google ID token and extracts the user's identity.
/// </summary>
public interface IGoogleTokenVerifier
{
    Task<GoogleUserInfo?> VerifyIdTokenAsync(
        string idToken,
        string? expectedClientId = null,
        CancellationToken cancellationToken = default);
}

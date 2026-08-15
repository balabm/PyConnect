#pragma warning disable CA1848

namespace PondyConnect.Infrastructure.Services;

using System.Net.Http.Json;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Verifies Google ID tokens against Google's tokeninfo endpoint.
/// </summary>
public sealed class GoogleTokenVerifier : IGoogleTokenVerifier
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<GoogleTokenVerifier> _logger;

    public GoogleTokenVerifier(IHttpClientFactory httpClientFactory, ILogger<GoogleTokenVerifier> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    public async Task<GoogleUserInfo?> VerifyIdTokenAsync(
        string idToken,
        string? expectedClientId = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            using var client = _httpClientFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(15);

            var response = await client.GetAsync(
                $"https://oauth2.googleapis.com/tokeninfo?id_token={Uri.EscapeDataString(idToken)}",
                cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "Google tokeninfo returned {StatusCode} for token",
                    response.StatusCode);
                return null;
            }

            var payload = await response.Content.ReadFromJsonAsync<GoogleTokenPayload>(
                cancellationToken: cancellationToken);

            if (payload is null)
                return null;

            // Validate the issuer.
            if (!string.Equals(payload.Iss, "https://accounts.google.com", StringComparison.Ordinal) &&
                !string.Equals(payload.Iss, "accounts.google.com", StringComparison.Ordinal))
            {
                _logger.LogWarning("Google token has invalid issuer: {Issuer}", payload.Iss);
                return null;
            }

            // Validate the audience if an expected web client ID is configured.
            if (!string.IsNullOrWhiteSpace(expectedClientId) &&
                !string.Equals(payload.Aud, expectedClientId, StringComparison.Ordinal))
            {
                _logger.LogWarning(
                    "Google token audience {Audience} does not match expected {Expected}",
                    payload.Aud,
                    expectedClientId);
                return null;
            }

            // Validate expiration.
            var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            if (payload.Exp > 0 && payload.Exp < now)
            {
                _logger.LogWarning("Google token is expired");
                return null;
            }

            // Email must be verified for a trusted social login.
            if (!payload.EmailVerified)
            {
                _logger.LogWarning("Google email is not verified for sub {Sub}", payload.Sub);
                return null;
            }

            return new GoogleUserInfo(
                payload.Sub,
                payload.Email,
                payload.EmailVerified,
                payload.Name,
                payload.Picture);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to verify Google ID token");
            return null;
        }
    }

    private sealed class GoogleTokenPayload
    {
        public string Iss { get; set; } = string.Empty;
        public string Aud { get; set; } = string.Empty;
        public string Sub { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public bool EmailVerified { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Picture { get; set; } = string.Empty;
        public long Exp { get; set; }
    }
}

#pragma warning restore CA1848

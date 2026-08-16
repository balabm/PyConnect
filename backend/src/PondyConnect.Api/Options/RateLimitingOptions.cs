namespace PondyConnect.Api;

/// <summary>
/// Configures rate limit policies bound from the "RateLimiting" appsettings section.
/// </summary>
public sealed class RateLimitingOptions
{
    public const string SectionName = "RateLimiting";

    /// <summary>
    /// Auth/OTP endpoints: 3 requests per 15-minute window per IP or phone.
    /// Tightened from 5/60s to prevent OTP brute-force and SMS-flooding.
    /// </summary>
    public AuthRateLimitOptions Auth { get; init; } = new();

    /// <summary>
    /// Global API throttle: 100 requests per minute per IP.
    /// </summary>
    public GlobalRateLimitOptions Global { get; init; } = new();
}

public sealed class AuthRateLimitOptions
{
    public int PermitLimit { get; init; } = 3;

    public int WindowSeconds { get; init; } = 900;

    public int QueueLimit { get; init; }
}

public sealed class GlobalRateLimitOptions
{
    public int PermitLimit { get; init; } = 100;

    public int WindowSeconds { get; init; } = 60;

    public int QueueLimit { get; init; }
}
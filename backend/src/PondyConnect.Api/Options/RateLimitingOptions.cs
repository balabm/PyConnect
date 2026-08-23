namespace PondyConnect.Api;

/// <summary>
/// Configures rate limit policies bound from the "RateLimiting" appsettings section.
/// </summary>
public sealed class RateLimitingOptions
{
    public const string SectionName = "RateLimiting";

    /// <summary>
    /// Auth/OTP endpoints: 30 requests per minute per IP or phone.
    /// Relaxed from 3/15min for demo usability while still preventing
    /// brute-force attacks.
    /// </summary>
    public AuthRateLimitOptions Auth { get; init; } = new();

    /// <summary>
    /// Global API throttle: 100 requests per minute per IP.
    /// </summary>
    public GlobalRateLimitOptions Global { get; init; } = new();
}

public sealed class AuthRateLimitOptions
{
    public int PermitLimit { get; init; } = 30;

    public int WindowSeconds { get; init; } = 60;

    public int QueueLimit { get; init; }
}

public sealed class GlobalRateLimitOptions
{
    public int PermitLimit { get; init; } = 300;

    public int WindowSeconds { get; init; } = 60;

    public int QueueLimit { get; init; }
}
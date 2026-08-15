namespace PondyConnect.Api;

/// <summary>
/// Configures rate limit policies bound from the "RateLimiting" appsettings section.
/// </summary>
public sealed class RateLimitingOptions
{
    public const string SectionName = "RateLimiting";

    /// <summary>
    /// Auth/OTP endpoints: 5 requests per 60-second window per IP or phone.
    /// </summary>
    public AuthRateLimitOptions Auth { get; init; } = new();

    /// <summary>
    /// Global API throttle: 100 requests per minute per IP.
    /// </summary>
    public GlobalRateLimitOptions Global { get; init; } = new();
}

public sealed class AuthRateLimitOptions
{
    public int PermitLimit { get; init; } = 5;

    public int WindowSeconds { get; init; } = 60;

    public int QueueLimit { get; init; }
}

public sealed class GlobalRateLimitOptions
{
    public int PermitLimit { get; init; } = 100;

    public int WindowSeconds { get; init; } = 60;

    public int QueueLimit { get; init; }
}
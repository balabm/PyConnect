namespace PondyConnect.Application.Services;

/// <summary>
/// Rate limiter for OTP request endpoints. Enforces a maximum number of
/// OTP requests per IP address and per phone number within a fixed time
/// window to prevent brute-force and SMS-flooding attacks.
/// </summary>
public interface IOtpRateLimiter
{
    /// <summary>
    /// The fixed-window duration used for rate limiting (15 minutes).
    /// </summary>
    TimeSpan Window { get; }

    /// <summary>
    /// Maximum number of OTP requests allowed within <see cref="Window"/>.
    /// </summary>
    int MaxRequests { get; }

    /// <summary>
    /// Attempts to consume a rate-limit slot for the given key. Returns
    /// <c>true</c> when the request is allowed, <c>false</c> when the
    /// caller has exceeded <see cref="MaxRequests"/> within the window.
    /// </summary>
    /// <param name="key">A composite key such as <c>otp:{ip}</c> or <c>otp:{phone}</c>.</param>
    Task<bool> TryConsumeAsync(string key);
}

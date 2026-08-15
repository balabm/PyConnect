namespace PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Generates and verifies OTP codes. The store is Redis-backed so codes
/// survive instance restarts and share state across replicas.
/// </summary>
public interface IOtpService
{
    Task<string> IssueCodeAsync(string phone, CancellationToken cancellationToken = default);

    Task<bool> VerifyCodeAsync(string phone, string code, CancellationToken cancellationToken = default);

    /// <summary>
    /// Returns the most recently issued plaintext OTP for a phone number.
    /// Only available when the system is in test/SMS-mock mode. In production
    /// with a real SMS provider, this returns null.
    /// </summary>
    Task<string?> PeekCodeAsync(string phone, CancellationToken cancellationToken = default);
}

public interface ISmsSender
{
    Task SendAsync(string phone, string message, CancellationToken cancellationToken = default);
}
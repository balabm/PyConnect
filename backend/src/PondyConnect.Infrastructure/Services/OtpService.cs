namespace PondyConnect.Infrastructure.Services;

using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Caching.Distributed;
using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// OTP lifecycle on top of Redis. Codes are stored hashed (never plaintext),
/// single-use, and expire after 5 minutes.
/// </summary>
public sealed class OtpService : IOtpService
{
    private readonly IDistributedCache _cache;
    private readonly bool _testMode;
    private static readonly TimeSpan s_lifetime = TimeSpan.FromMinutes(5);

    public OtpService(IDistributedCache cache, bool testMode = false)
    {
        _cache = cache;
        _testMode = testMode;
    }

    public async Task<string> IssueCodeAsync(string phone, CancellationToken cancellationToken = default)
    {
        var code = RandomNumberGenerator.GetInt32(100_000, 1_000_000).ToString("D6", CultureInfo.InvariantCulture);
        var payload = JsonSerializer.Serialize(new OtpRecord(HashCode(code), Attempts: 0));
        await _cache.SetStringAsync(KeyFor(phone), payload, new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = s_lifetime
        }, cancellationToken);

        // In test/SMS-mock mode, also stash the plaintext code in a separate
        // peek key so the Flutter app can autofill it during testing. This key
        // is never written in production with a real SMS provider.
        if (_testMode)
        {
            await _cache.SetStringAsync(PeekKeyFor(phone), code, new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = s_lifetime
            }, cancellationToken);
        }

        return code;
    }

    public async Task<string?> PeekCodeAsync(string phone, CancellationToken cancellationToken = default)
    {
        if (!_testMode)
            return null;
        return await _cache.GetStringAsync(PeekKeyFor(phone), cancellationToken);
    }

    public async Task<bool> VerifyCodeAsync(string phone, string code, CancellationToken cancellationToken = default)
    {
        var stored = await _cache.GetStringAsync(KeyFor(phone), cancellationToken);
        if (stored is null)
            return false;

        var record = JsonSerializer.Deserialize<OtpRecord>(stored);
        if (record is null || record.Attempts >= 5)
        {
            await _cache.RemoveAsync(KeyFor(phone), cancellationToken);
            return false;
        }

        var isMatch = FixedTimeEquals(record.HashedCode, HashCode(code));
        if (isMatch)
        {
            await _cache.RemoveAsync(KeyFor(phone), cancellationToken);
            if (_testMode)
                await _cache.RemoveAsync(PeekKeyFor(phone), cancellationToken);
        }
        else
            await _cache.SetStringAsync(KeyFor(phone), JsonSerializer.Serialize(record with { Attempts = record.Attempts + 1 }), new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = s_lifetime
            }, cancellationToken);

        return isMatch;
    }

    private static string HashCode(string code)
        => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(code)));

    private static bool FixedTimeEquals(string a, string b)
        => CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(a), Encoding.UTF8.GetBytes(b));

    private static string KeyFor(string phone) => $"otp:{phone}";

    private static string PeekKeyFor(string phone) => $"otp:peek:{phone}";

    private sealed record OtpRecord(string HashedCode, int Attempts);
}
namespace PondyConnect.Application.Features.Auth;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

/// <summary>
/// Orchestrates the "Right to be Forgotten" flow for both consumers and
/// drivers. Ensures that KYC documents are shredded from S3/storage BEFORE
/// the database record is anonymized, satisfying DPDP Act mandates.
///
/// The flow is:
/// 1. If the user has a driver profile, shred all KYC documents from storage.
/// 2. Anonymize the driver record (clear URL fields, PII).
/// 3. Anonymize the user record (Name, Phone, Email, etc.).
/// 4. Hard-delete saved locations (PII).
/// 5. Deactivate the account so it can never be logged into again.
///
/// Financial ledgers (orders, rides, wallet transactions) remain intact
/// for tax auditing, but are permanently severed from any human identity.
/// </summary>
public sealed class AccountDeletionService
{
    private readonly IApplicationDbContext _context;
    private readonly IStorageService _storage;
    private readonly ILogger<AccountDeletionService> _logger;

    public AccountDeletionService(
        IApplicationDbContext context,
        IStorageService storage,
        ILogger<AccountDeletionService> logger)
    {
        _context = context;
        _storage = storage;
        _logger = logger;
    }

    /// <summary>
    /// Deletes a user account and all associated PII. If the user is a
    /// driver, their KYC documents are shredded from storage first.
    /// Returns a summary of what was deleted/anonymized.
    /// </summary>
    public async Task<AccountDeletionResult> DeleteAccountAsync(
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new InvalidOperationException("User not found.");

        var result = new AccountDeletionResult();

        // ── Step 1: Shred driver KYC documents from storage ──────────────
        var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken);
        if (driver is not null)
        {
            var kycUrls = driver.GetKycDocumentUrls();
            result.KycDocumentsFound = kycUrls.Count;

            foreach (var url in kycUrls)
            {
                try
                {
                    var deleted = await _storage.DeleteFileAsync(url, cancellationToken);
                    if (deleted)
                        result.KycDocumentsShredded++;
                }
                catch (Exception ex)
                {
                    _logger.KycShredFailed(url, ex);
                }
            }

            // Anonymize the driver record (clears all URL fields and PII).
            driver.AnonymizeForDeletion();
            _logger.DriverAnonymized(driver.Id);
        }

        // ── Step 2: Anonymize the user record ────────────────────────────
        user.AnonymizeForDeletion();
        _logger.UserAnonymized(userId);

        // ── Step 3: Hard-delete saved locations (PII) ────────────────────
        var savedLocations = await _context.SavedLocations
            .Where(l => l.UserId == userId)
            .ToListAsync(cancellationToken);
        if (savedLocations.Count > 0)
        {
            _context.SavedLocations.RemoveRange(savedLocations);
            result.SavedLocationsDeleted = savedLocations.Count;
        }

        await _context.SaveChangesAsync(cancellationToken);

        _logger.AccountDeletionComplete(userId, result.KycDocumentsShredded, result.SavedLocationsDeleted);
        return result;
    }
}

/// <summary>
/// Summary of what was deleted/anonymized during the account deletion flow.
/// </summary>
public sealed class AccountDeletionResult
{
    /// <summary>Number of KYC document URLs found on the driver profile.</summary>
    public int KycDocumentsFound { get; set; }

    /// <summary>Number of KYC documents successfully shredded from storage.</summary>
    public int KycDocumentsShredded { get; set; }

    /// <summary>Number of saved locations hard-deleted from the database.</summary>
    public int SavedLocationsDeleted { get; set; }
}

internal static partial class AccountDeletionLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Warning, Message = "Failed to shred KYC document {Url} from storage")]
    public static partial void KycShredFailed(this ILogger logger, string url, Exception ex);

    [LoggerMessage(Level = LogLevel.Information, Message = "Driver {DriverId} anonymized — KYC URLs cleared")]
    public static partial void DriverAnonymized(this ILogger logger, Guid driverId);

    [LoggerMessage(Level = LogLevel.Information, Message = "User {UserId} anonymized — PII cleared")]
    public static partial void UserAnonymized(this ILogger logger, Guid userId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Account deletion complete for {UserId}: {KycShredded} KYC docs shredded, {LocationsDeleted} saved locations deleted")]
    public static partial void AccountDeletionComplete(this ILogger logger, Guid userId, int kycShredded, int locationsDeleted);
}

namespace PondyConnect.Application.Services;

/// <summary>
/// Result of an automated driving-license verification via OCR.
/// </summary>
public sealed record DocumentVerificationResult(
    bool Success,
    string? ParsedName,
    string? LicenseNumber,
    DateTime? ExpiryDate,
    double Confidence,
    bool AutoApproved,
    string Reason);

/// <summary>
/// Pluggable document verification service that uses an OCR provider
/// (Google Cloud Vision or AWS Textract) to extract structured data from
/// uploaded driving-license images and auto-approve drivers when the
/// extracted data matches their profile with high confidence.
/// </summary>
public interface IDocumentVerificationService
{
    /// <summary>
    /// Verifies a driving-license image by running it through an OCR
    /// provider, extracting the holder name, license number, and expiry
    /// date, then deciding whether the driver can be auto-approved.
    /// </summary>
    /// <param name="documentUrl">Storage key / URL of the uploaded license image.</param>
    /// <param name="userProfileName">The driver's registered name to match against.</param>
    /// <param name="ct">Cancellation token.</param>
    Task<DocumentVerificationResult> VerifyDrivingLicenseAsync(
        string documentUrl,
        string userProfileName,
        CancellationToken ct);
}

namespace PondyConnect.Infrastructure.Services;

using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Configuration;
using PondyConnect.Application.Services;

/// <summary>
/// Pluggable document verification service that selects an OCR provider via
/// configuration and extracts driving license fields from the returned text.
/// When no OCR provider is configured (or credentials are missing) the service
/// falls back to a manual-review result so the system remains operational.
/// </summary>
public sealed class DocumentVerificationService : IDocumentVerificationService
{
    private readonly IConfiguration _configuration;

    public DocumentVerificationService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public async Task<DocumentVerificationResult> VerifyDrivingLicenseAsync(
        string documentUrl,
        string userProfileName,
        CancellationToken ct)
    {
        var provider = _configuration.GetValue<string>("Ocr:Provider") ?? "None";

        if (string.IsNullOrWhiteSpace(provider) ||
            string.Equals(provider, "None", StringComparison.OrdinalIgnoreCase))
        {
            return Fallback("OCR provider not configured — manual review required");
        }

        if (string.Equals(provider, "GoogleVision", StringComparison.OrdinalIgnoreCase))
        {
            var apiKey = _configuration.GetValue<string>("Ocr:GoogleVision:ApiKey");
            if (string.IsNullOrWhiteSpace(apiKey))
                return Fallback("OCR provider not configured — manual review required");

            var text = await CallGoogleVisionAsync(documentUrl, apiKey, ct);
            return ParseResult(text, userProfileName);
        }

        if (string.Equals(provider, "AwsTextract", StringComparison.OrdinalIgnoreCase))
        {
            var accessKey = _configuration.GetValue<string>("Ocr:AwsTextract:AccessKey");
            var secretKey = _configuration.GetValue<string>("Ocr:AwsTextract:SecretKey");
            if (string.IsNullOrWhiteSpace(accessKey) || string.IsNullOrWhiteSpace(secretKey))
                return Fallback("OCR provider not configured — manual review required");

            var text = await CallAwsTextractAsync(documentUrl, accessKey, secretKey, ct);
            return ParseResult(text, userProfileName);
        }

        return Fallback("OCR provider not configured — manual review required");
    }

    private static DocumentVerificationResult Fallback(string reason) =>
        new(false, null, null, null, 0.0, false, reason);

    private static async Task<string> CallGoogleVisionAsync(
        string documentUrl,
        string apiKey,
        CancellationToken ct)
    {
        // TODO: Call Google Cloud Vision API:
        // POST https://vision.googleapis.com/v1/images:annotate?key={apiKey}
        // with the document image and parse the fullTextAnnotation text.
        await Task.Yield();
        return string.Empty;
    }

    private static async Task<string> CallAwsTextractAsync(
        string documentUrl,
        string accessKey,
        string secretKey,
        CancellationToken ct)
    {
        // TODO: Call AWS Textract DetectDocumentText and concatenate LINE blocks.
        await Task.Yield();
        return string.Empty;
    }

    private static DocumentVerificationResult ParseResult(string rawText, string userProfileName)
    {
        var parsedName = ExtractName(rawText);
        var licenseNumber = ExtractLicenseNumber(rawText);
        var expiryDate = ExtractExpiryDate(rawText);

        var confidence = ComputeConfidence(parsedName, licenseNumber, expiryDate);
        var success = !string.IsNullOrEmpty(licenseNumber) && expiryDate.HasValue;

        var autoApproved = success
            && confidence >= 0.85
            && !string.IsNullOrEmpty(parsedName)
            && parsedName.Trim().Equals(userProfileName.Trim(), StringComparison.OrdinalIgnoreCase)
            && expiryDate!.Value > DateTime.UtcNow;

        var reason = autoApproved
            ? $"Auto-approved via OCR with confidence {confidence:P0}"
            : !success
                ? "OCR could not reliably extract license details."
                : "OCR parsed the document but did not meet auto-approval criteria.";

        return new DocumentVerificationResult(
            success,
            parsedName,
            licenseNumber,
            expiryDate,
            confidence,
            autoApproved,
            reason);
    }

    private static double ComputeConfidence(string? name, string? licenseNumber, DateTime? expiryDate)
    {
        var score = 0.0;
        if (!string.IsNullOrEmpty(name)) score += 0.30;
        if (!string.IsNullOrEmpty(licenseNumber)) score += 0.35;
        if (expiryDate.HasValue) score += 0.35;
        return score;
    }

    private static string? ExtractName(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        foreach (var line in text.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries))
        {
            var candidate = line.Trim();
            if (Regex.IsMatch(candidate, @"^[A-Z][a-z]+(\s+[A-Z][a-z]+){1,3}$"))
                return candidate;
        }

        return null;
    }

    private static string? ExtractLicenseNumber(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var match = Regex.Match(text, @"\b[A-Z]{2}\d{2}\s?\d{11,}\b");
        return match.Success ? match.Value : null;
    }

    private static DateTime? ExtractExpiryDate(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var match = Regex.Match(text, @"\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b");
        if (!match.Success) return null;

        var formats = new[]
        {
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "dd/MM/yy",
            "dd-MM-yy",
            "MM/dd/yy",
            "MM-dd-yy"
        };

        if (DateTime.TryParseExact(
            match.Value,
            formats,
            CultureInfo.InvariantCulture,
            DateTimeStyles.None,
            out var parsed))
        {
            if (parsed.Year < 100)
                parsed = parsed.AddYears(parsed.Year < 50 ? 2000 : 1900);

            return parsed;
        }

        return null;
    }
}

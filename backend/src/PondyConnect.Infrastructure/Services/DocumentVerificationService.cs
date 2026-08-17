namespace PondyConnect.Infrastructure.Services;

using System.Globalization;
using System.Net.Http;
using System.Text.RegularExpressions;
using Google.Api.Gax.Grpc;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.Vision.V1;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PondyConnect.Application.Common;
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
    private readonly IServiceProvider _serviceProvider;

    public DocumentVerificationService(IConfiguration configuration, IServiceProvider serviceProvider)
    {
        _configuration = configuration;
        _serviceProvider = serviceProvider;
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
            var googleCredentials = _configuration.GetValue<string>("Ocr:GoogleCredentials");
            var googleCredentialsPath = _configuration.GetValue<string>("Ocr:GoogleCredentialsPath");

            if (string.IsNullOrWhiteSpace(googleCredentials) &&
                (string.IsNullOrWhiteSpace(googleCredentialsPath) || !File.Exists(googleCredentialsPath)))
            {
                return Fallback("Google Vision credentials not configured — manual review required");
            }

            try
            {
                var client = _serviceProvider.GetRequiredService<ImageAnnotatorClient>();
                var text = await CallGoogleVisionAsync(client, documentUrl, ct);
                return ParseResult(text, userProfileName);
            }
            catch (Exception ex)
            {
                return Fallback($"Google Vision OCR failed: {ex.Message}");
            }
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
        ImageAnnotatorClient client,
        string documentUrl,
        CancellationToken ct)
    {
        using var http = new HttpClient();
        var imageBytes = await LoadImageBytesAsync(documentUrl, http, ct);
        var image = Image.FromBytes(imageBytes);
        var response = await client.DetectTextAsync(image, null, 0, CallSettings.FromCancellationToken(ct));
        return response.Count > 0 ? response[0].Description : string.Empty;
    }

    private static async Task<byte[]> LoadImageBytesAsync(string documentUrl, HttpClient http, CancellationToken ct)
    {
        if (Uri.TryCreate(documentUrl, UriKind.Absolute, out var uri) &&
            (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps))
        {
            return await http.GetByteArrayAsync(documentUrl, ct);
        }

        if (File.Exists(documentUrl))
        {
            return await File.ReadAllBytesAsync(documentUrl, ct);
        }

        throw new FileNotFoundException("Document image not found.", documentUrl);
    }

    private static async Task<string> CallAwsTextractAsync(
        string documentUrl,
        string accessKey,
        string secretKey,
        CancellationToken ct)
    {
        await Task.Yield();
        return string.Empty;
    }

    private DocumentVerificationResult ParseResult(string rawText, string userProfileName)
    {
        var parsedName = ExtractName(rawText);
        var licenseNumber = ExtractLicenseNumber(rawText);
        var expiryDate = ExtractExpiryDate(rawText);

        var confidence = ComputeConfidence(parsedName, licenseNumber, expiryDate);
        var success = !string.IsNullOrEmpty(licenseNumber) && expiryDate.HasValue;

        var threshold = _configuration.GetValue<double>("Ocr:AutoApproveThreshold", 0.85);
        var nameSimilarity = string.IsNullOrEmpty(parsedName) ? 0.0 : StringSimilarity.Similarity(parsedName, userProfileName);

        var autoApproved = success
            && confidence >= threshold
            && !string.IsNullOrEmpty(parsedName)
            && nameSimilarity >= 0.85
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

        var lines = text
            .Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(l => l.Trim())
            .Where(l => !string.IsNullOrWhiteSpace(l))
            .ToList();

        for (var i = 0; i < lines.Count; i++)
        {
            if (lines[i].StartsWith("Name", StringComparison.OrdinalIgnoreCase) && i + 1 < lines.Count)
            {
                var next = lines[i + 1];
                if (!string.IsNullOrWhiteSpace(next))
                    return next;
            }

            if (Regex.IsMatch(lines[i], @"^[A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,3}$"))
                return lines[i];
        }

        return null;
    }

    private static string? ExtractLicenseNumber(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var match = Regex.Match(text, @"\b[A-Z]{2}\d{2}\s?\d{11}\b");
        if (match.Success) return match.Value;

        match = Regex.Match(
            text,
            @"(?:DL No|Licence No|License Number|DL Number)[^\w\n\r]*([A-Z]{2}\d{2}\s?\d{11})",
            RegexOptions.IgnoreCase);

        return match.Success ? match.Groups[1].Value : null;
    }

    private static DateTime? ExtractExpiryDate(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var patterns = new[]
        {
            new { Pattern = @"Valid Till[:\s]*(\d{2}/\d{2}/\d{4})", Format = "dd/MM/yyyy" },
            new { Pattern = @"Valid Upto[:\s]*(\d{2}-\d{2}-\d{4})", Format = "dd-MM-yyyy" },
            new { Pattern = @"Expiry[:\s]*(\d{4}-\d{2}-\d{2})", Format = "yyyy-MM-dd" },
        };

        foreach (var p in patterns)
        {
            var match = Regex.Match(text, p.Pattern, RegexOptions.IgnoreCase);
            if (match.Success &&
                DateTime.TryParseExact(
                    match.Groups[1].Value,
                    p.Format,
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.None,
                    out var parsed))
            {
                return parsed;
            }
        }

        var genericMatch = Regex.Match(text, @"\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b");
        if (!genericMatch.Success) return null;

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
            genericMatch.Value,
            formats,
            CultureInfo.InvariantCulture,
            DateTimeStyles.None,
            out var parsedGeneric))
        {
            if (parsedGeneric.Year < 100)
                parsedGeneric = parsedGeneric.AddYears(parsedGeneric.Year < 50 ? 2000 : 1900);

            return parsedGeneric;
        }

        return null;
    }
}

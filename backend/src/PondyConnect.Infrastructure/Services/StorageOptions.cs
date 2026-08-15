namespace PondyConnect.Infrastructure.Services;

/// <summary>
/// Configuration for cloud storage (AWS S3). Bound from the "Storage" section.
/// </summary>
public sealed class StorageOptions
{
    public const string SectionName = "Storage";

    public bool UseMock { get; set; } = true;
    public string PublicBucket { get; set; } = "pondyconnect-public";
    public string PrivateBucket { get; set; } = "pondyconnect-private";
    public string Region { get; set; } = "ap-south-1";
    public int PresignedUrlExpiryMinutes { get; set; } = 60;
}

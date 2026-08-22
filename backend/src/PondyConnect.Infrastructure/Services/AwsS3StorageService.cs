namespace PondyConnect.Infrastructure.Services;

using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// AWS S3-backed storage for production. Public files (vendor images, venue
/// photos) go to a public-read bucket; private files (driver KYC documents)
/// go to a private bucket and are viewed via presigned URLs.
/// </summary>
public sealed class AwsS3StorageService : IStorageService
{
    private static readonly Action<ILogger, string, string, Exception?> s_uploadOk =
        LoggerMessage.Define<string, string>(
            LogLevel.Information,
            new EventId(1, "FileUploaded"),
            "Uploaded {FileName} to S3 bucket -> {Key}");

    private static readonly Action<ILogger, string, Exception?> s_presignOk =
        LoggerMessage.Define<string>(
            LogLevel.Information,
            new EventId(2, "PresignedUrl"),
            "Generated presigned URL for {Key}");

    private readonly IAmazonS3 _client;
    private readonly StorageOptions _options;
    private readonly ILogger<AwsS3StorageService> _logger;

    public AwsS3StorageService(
        IAmazonS3 client,
        IOptions<StorageOptions> options,
        ILogger<AwsS3StorageService> logger)
    {
        _client = client;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<string> UploadFileAsync(
        Stream fileStream,
        string fileName,
        string contentType,
        bool isPrivate = false,
        CancellationToken cancellationToken = default)
    {
        var bucket = isPrivate ? _options.PrivateBucket : _options.PublicBucket;
        var ext = Path.GetExtension(fileName);
        var key = $"{(isPrivate ? "kyc" : "public")}/{Guid.NewGuid():N}{ext}";

        var request = new PutObjectRequest
        {
            BucketName = bucket,
            Key = key,
            InputStream = fileStream,
            ContentType = contentType,
            // Private bucket: no ACL (default private). Public bucket: public-read.
            CannedACL = isPrivate ? S3CannedACL.Private : S3CannedACL.PublicRead,
        };

        await _client.PutObjectAsync(request, cancellationToken);
        s_uploadOk(_logger, fileName, key, null);

        // For public files, return the public URL. For private files, return the
        // object key so the caller can request a presigned URL later.
        if (isPrivate)
            return key;

        return $"https://{bucket}.s3.{_options.Region}.amazonaws.com/{key}";
    }

    public async Task<string> GetPresignedUrlAsync(
        string objectKey,
        int expiryMinutes = 60,
        CancellationToken cancellationToken = default)
    {
        // Presigned URLs are only meaningful for the private bucket.
        var expiry = DateTime.UtcNow.AddMinutes(
            expiryMinutes > 0 ? expiryMinutes : _options.PresignedUrlExpiryMinutes);

        var request = new GetPreSignedUrlRequest
        {
            BucketName = _options.PrivateBucket,
            Key = objectKey,
            Expires = expiry,
            Verb = HttpVerb.GET,
        };

        var url = await _client.GetPreSignedURLAsync(request);
        s_presignOk(_logger, objectKey, null);
        return url;
    }

    private static readonly Action<ILogger, string, Exception?> s_deleteOk =
        LoggerMessage.Define<string>(
            LogLevel.Information,
            new EventId(3, "FileDeleted"),
            "Deleted S3 object -> {Key}");

    private static readonly Action<ILogger, string, Exception?> s_deleteSkip =
        LoggerMessage.Define<string>(
            LogLevel.Information,
            new EventId(4, "FileDeleteSkipped"),
            "S3 object not found (already deleted?) -> {Key}");

    public async Task<bool> DeleteFileAsync(
        string objectKeyOrUrl,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(objectKeyOrUrl))
            return true;

        // Determine which bucket to delete from. Private KYC documents are
        // stored as object keys (e.g. "uploads/private/xxx.jpg"); public
        // files are stored as full URLs.
        var (bucket, key) = ResolveBucketAndKey(objectKeyOrUrl);

        try
        {
            // Check if the object exists first so we can log meaningfully.
            try
            {
                await _client.GetObjectMetadataAsync(bucket, key, cancellationToken);
            }
            catch (AmazonS3Exception ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
            {
                s_deleteSkip(_logger, key, null);
                return true; // Already deleted — treat as success.
            }

            await _client.DeleteObjectAsync(bucket, key, cancellationToken);
            s_deleteOk(_logger, key, null);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete S3 object {Key} from bucket {Bucket}", key, bucket);
            return false;
        }
    }

    /// <summary>
    /// Resolves which S3 bucket and object key to use for a given URL or key.
    /// Private KYC documents are stored as relative paths (e.g.
    /// "uploads/private/xxx.jpg"); public files are stored as full HTTPS URLs.
    /// </summary>
    private (string bucket, string key) ResolveBucketAndKey(string objectKeyOrUrl)
    {
        // If it's a full URL, extract the key after the bucket hostname.
        if (objectKeyOrUrl.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            var uri = new Uri(objectKeyOrUrl);
            var key = uri.AbsolutePath.TrimStart('/');

            // If the URL contains the private bucket name, use it.
            if (uri.Host.StartsWith(_options.PrivateBucket, StringComparison.OrdinalIgnoreCase))
                return (_options.PrivateBucket, key);

            return (_options.PublicBucket, key);
        }

        // Relative path — assume private bucket for KYC docs.
        // Strip any leading "uploads/private/" prefix to get the raw key.
        var cleanKey = objectKeyOrUrl.Replace("uploads/private/", "", StringComparison.OrdinalIgnoreCase);
        cleanKey = cleanKey.TrimStart('/');
        return (_options.PrivateBucket, cleanKey);
    }
}

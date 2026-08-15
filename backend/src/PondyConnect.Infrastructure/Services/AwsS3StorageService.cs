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
}

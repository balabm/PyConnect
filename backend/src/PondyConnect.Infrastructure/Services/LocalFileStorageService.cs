namespace PondyConnect.Infrastructure.Services;

using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Local filesystem storage for development. Saves files to wwwroot/uploads
/// and returns relative URLs. Private files are stored in a separate
/// "private" subdirectory and served via a presigned-style token URL.
/// </summary>
public sealed class LocalFileStorageService : IStorageService
{
    private static readonly Action<ILogger, string, string, Exception?> s_uploadOk =
        LoggerMessage.Define<string, string>(
            LogLevel.Information,
            new EventId(1, "FileUploaded"),
            "Saved {FileName} to local storage -> {Path}");

    private readonly string _webRootPath;
    private readonly string _contentRootPath;
    private readonly ILogger<LocalFileStorageService> _logger;

    public LocalFileStorageService(
        IHostEnvironment environment,
        ILogger<LocalFileStorageService> logger)
    {
        _contentRootPath = environment.ContentRootPath;
        _webRootPath = Path.Combine(_contentRootPath, "wwwroot");
        _logger = logger;
    }

    public async Task<string> UploadFileAsync(
        Stream fileStream,
        string fileName,
        string contentType,
        bool isPrivate = false,
        CancellationToken cancellationToken = default)
    {
        var subdir = isPrivate ? "uploads/private" : "uploads";
        var uploadDir = Path.Combine(_webRootPath, subdir);
        Directory.CreateDirectory(uploadDir);

        var ext = Path.GetExtension(fileName);
        var storedName = $"{Guid.NewGuid():N}{ext}";
        var fullPath = Path.Combine(uploadDir, storedName);

        await using var fs = File.Create(fullPath);
        await fileStream.CopyToAsync(fs, cancellationToken);
        s_uploadOk(_logger, fileName, fullPath, null);

        // For public files, return a relative URL. For private files, return a
        // relative path that the caller can use with GetPresignedUrlAsync.
        if (isPrivate)
            return $"uploads/private/{storedName}";

        return $"/uploads/{storedName}";
    }

    public Task<string> GetPresignedUrlAsync(
        string objectKey,
        int expiryMinutes = 60,
        CancellationToken cancellationToken = default)
    {
        // In local dev, we just return the direct path. A real presigned URL
        // would embed an expiry token, but for local development this is fine.
        var key = objectKey.StartsWith("uploads/", StringComparison.Ordinal) ? objectKey : $"uploads/private/{objectKey}";
        return Task.FromResult($"/{key}");
    }

    private static readonly Action<ILogger, string, Exception?> s_deleteOk =
        LoggerMessage.Define<string>(
            LogLevel.Information,
            new EventId(2, "FileDeleted"),
            "Deleted local file -> {Path}");

    private static readonly Action<ILogger, string, Exception?> s_deleteSkip =
        LoggerMessage.Define<string>(
            LogLevel.Information,
            new EventId(3, "FileDeleteSkipped"),
            "Local file not found (already deleted?) -> {Path}");

    public Task<bool> DeleteFileAsync(
        string objectKeyOrUrl,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(objectKeyOrUrl))
            return Task.FromResult(true);

        try
        {
            // Resolve the local filesystem path from the URL/key.
            // URLs like "/uploads/xxx.jpg" or "uploads/private/xxx.jpg"
            string relativePath;
            if (objectKeyOrUrl.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            {
                // In local dev, full URLs shouldn't exist. Extract the path.
                var uri = new Uri(objectKeyOrUrl);
                relativePath = uri.AbsolutePath.TrimStart('/');
            }
            else if (objectKeyOrUrl.StartsWith("/uploads/", StringComparison.OrdinalIgnoreCase))
            {
                relativePath = objectKeyOrUrl.TrimStart('/');
            }
            else if (objectKeyOrUrl.StartsWith("uploads/", StringComparison.OrdinalIgnoreCase))
            {
                relativePath = objectKeyOrUrl;
            }
            else
            {
                // Raw object key — assume private uploads.
                relativePath = $"uploads/private/{objectKeyOrUrl}";
            }

            var fullPath = Path.Combine(_webRootPath, relativePath);

            if (!File.Exists(fullPath))
            {
                s_deleteSkip(_logger, fullPath, null);
                return Task.FromResult(true); // Already deleted — treat as success.
            }

            File.Delete(fullPath);
            s_deleteOk(_logger, fullPath, null);
            return Task.FromResult(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete local file {Key}", objectKeyOrUrl);
            return Task.FromResult(false);
        }
    }
}

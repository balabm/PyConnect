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
}

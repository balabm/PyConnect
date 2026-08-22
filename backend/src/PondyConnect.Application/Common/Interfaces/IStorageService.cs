namespace PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Abstraction over file storage (AWS S3 in production, local filesystem in
/// development). Used for driver KYC documents, vendor images, and other
/// uploads that must be persisted outside the database.
/// </summary>
public interface IStorageService
{
    /// <summary>
    /// Uploads a file and returns a publicly-accessible URL (for public
    /// files) or an object key (for private files that require a presigned
    /// URL to view).
    /// </summary>
    /// <param name="fileStream">The file content stream.</param>
    /// <param name="fileName">The original file name (used for key generation).</param>
    /// <param name="contentType">MIME type, e.g. "image/jpeg".</param>
    /// <param name="isPrivate">When true, uploads to a private bucket (KYC docs).
    /// When false, uploads to a public-read bucket.</param>
    /// <returns>A URL (public) or object key (private) that identifies the uploaded file.</returns>
    Task<string> UploadFileAsync(
        Stream fileStream,
        string fileName,
        string contentType,
        bool isPrivate = false,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Generates a time-limited presigned URL for viewing a private object
    /// (e.g. a KYC document on the Admin dashboard).
    /// </summary>
    /// <param name="objectKey">The object key returned by <see cref="UploadFileAsync"/>.</param>
    /// <param name="expiryMinutes">How long the URL remains valid.</param>
    Task<string> GetPresignedUrlAsync(
        string objectKey,
        int expiryMinutes = 60,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Permanently deletes a file from storage. Used by the "Right to be
    /// Forgotten" flow to shred KYC documents (Aadhaar, Driving License, RC,
    /// Insurance, Selfie) when a driver deletes their account.
    /// </summary>
    /// <param name="objectKeyOrUrl">The object key or URL returned by <see cref="UploadFileAsync"/>.</param>
    /// <returns>True if the file was deleted (or did not exist); false if deletion failed.</returns>
    Task<bool> DeleteFileAsync(
        string objectKeyOrUrl,
        CancellationToken cancellationToken = default);
}

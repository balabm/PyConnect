namespace PondyConnect.Application.Features.RideHailing;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Services;
using PondyConnect.Domain.Entities;

public sealed record UploadKycCommand(
    string AadhaarUrl,
    string DrivingLicenseUrl,
    string RcUrl,
    string UpiId) : IRequest<KycUploadResponse>;

public sealed record KycUploadResponse(
    bool Success,
    string Message,
    bool IsKycUploaded);

public sealed class UploadKycHandler : IRequestHandler<UploadKycCommand, KycUploadResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IDocumentVerificationService _verificationService;

    public UploadKycHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IDocumentVerificationService verificationService)
    {
        _context = context;
        _currentUser = currentUser;
        _verificationService = verificationService;
    }

    public async Task<KycUploadResponse> Handle(UploadKycCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");

        var driver = await _context.Drivers
            .FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken);

        if (driver is null)
            return new KycUploadResponse(false, "Driver profile not found.", false);

        var verification = await _verificationService.VerifyDrivingLicenseAsync(
            request.DrivingLicenseUrl,
            driver.Name,
            cancellationToken);

        driver.UploadKyc(request.AadhaarUrl, request.DrivingLicenseUrl, request.RcUrl, request.UpiId);
        driver.RecordKycVerification(
            verification.AutoApproved,
            verification.Confidence,
            verification.Reason,
            verification.ParsedName,
            verification.LicenseNumber,
            verification.ExpiryDate);

        if (verification.AutoApproved)
            driver.Approve();

        await _context.SaveChangesAsync(cancellationToken);

        var message = verification.AutoApproved
            ? $"KYC auto-approved via OCR with confidence {verification.Confidence:P0}."
            : "KYC documents uploaded successfully. Awaiting admin approval.";

        return new KycUploadResponse(true, message, true);
    }
}

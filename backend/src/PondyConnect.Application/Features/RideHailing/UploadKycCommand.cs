namespace PondyConnect.Application.Features.RideHailing;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
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

    public UploadKycHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<KycUploadResponse> Handle(UploadKycCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");

        var driver = await _context.Drivers
            .FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken);

        if (driver is null)
            return new KycUploadResponse(false, "Driver profile not found.", false);

        driver.UploadKyc(request.AadhaarUrl, request.DrivingLicenseUrl, request.RcUrl, request.UpiId);
        await _context.SaveChangesAsync(cancellationToken);

        return new KycUploadResponse(true, "KYC documents uploaded successfully. Awaiting admin approval.", true);
    }
}

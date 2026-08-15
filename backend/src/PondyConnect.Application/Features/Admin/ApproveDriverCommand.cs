namespace PondyConnect.Application.Features.Admin;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;

public sealed record ApproveDriverCommand(Guid DriverId) : IRequest<ApproveDriverResponse>;

public sealed record ApproveDriverResponse(
    bool Success,
    string DriverName,
    string Message);

public sealed class ApproveDriverHandler : IRequestHandler<ApproveDriverCommand, ApproveDriverResponse>
{
    private readonly IApplicationDbContext _context;

    public ApproveDriverHandler(IApplicationDbContext context) => _context = context;

    public async Task<ApproveDriverResponse> Handle(ApproveDriverCommand request, CancellationToken cancellationToken)
    {
        var driver = await _context.Drivers
            .FirstOrDefaultAsync(d => d.Id == request.DriverId, cancellationToken);

        if (driver is null)
            return new ApproveDriverResponse(false, string.Empty, "Driver not found.");

        if (!driver.IsKycUploaded)
            return new ApproveDriverResponse(false, driver.Name, "Driver has not uploaded KYC documents yet.");

        if (driver.IsApproved)
            return new ApproveDriverResponse(true, driver.Name, "Driver is already approved.");

        driver.Approve();
        await _context.SaveChangesAsync(cancellationToken);

        return new ApproveDriverResponse(true, driver.Name, "Driver approved successfully.");
    }
}

namespace PondyConnect.Application.Features.Admin;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Notifications;

public sealed record ApproveDriverCommand(Guid DriverId) : IRequest<ApproveDriverResponse>;

public sealed record ApproveDriverResponse(
    bool Success,
    string DriverName,
    string Message);

public sealed class ApproveDriverHandler : IRequestHandler<ApproveDriverCommand, ApproveDriverResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly INotificationService _notifications;

    public ApproveDriverHandler(IApplicationDbContext context, INotificationService notifications)
    {
        _context = context;
        _notifications = notifications;
    }

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

        // Notify the Captain app that KYC has been approved so the shell
        // unlocks and the driver can go online. Failures are best-effort.
        try
        {
            await _notifications.SendTargetedPushAsync(
                driver.UserId,
                "You are approved!",
                "Your KYC has been verified. Go online and start earning with PY Connect.",
                new Dictionary<string, string>
                {
                    { "type", "driver_approved" },
                    { "route", "/" },
                },
                cancellationToken);
        }
        catch
        {
            // Ignore FCM failures — the approval is already persisted and the
            // driver can still pull the latest profile on their next refresh.
        }

        return new ApproveDriverResponse(true, driver.Name, "Driver approved successfully.");
    }
}

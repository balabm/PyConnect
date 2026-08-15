namespace PondyConnect.Application.Features.Admin;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

// === User Management ===

public sealed record ListUsersQuery(
    string? Search = null,
    UserRole? Role = null,
    bool? IsActive = null,
    int Page = 1,
    int PageSize = 50) : IRequest<PagedResult<UserSummaryResponse>>;

public sealed record UserSummaryResponse(
    Guid Id,
    string Name,
    string Phone,
    string Role,
    bool IsActive,
    bool IsProMember,
    bool IsVerifiedLocal,
    string KycStatus,
    DateTimeOffset? LastLoginAt,
    DateTimeOffset CreatedAt);

public sealed record PagedResult<T>(IReadOnlyList<T> Items, int TotalCount, int Page, int PageSize);

public sealed class ListUsersHandler : IRequestHandler<ListUsersQuery, PagedResult<UserSummaryResponse>>
{
    private readonly IApplicationDbContext _context;

    public ListUsersHandler(IApplicationDbContext context) => _context = context;

    public async Task<PagedResult<UserSummaryResponse>> Handle(ListUsersQuery request, CancellationToken cancellationToken)
    {
        var query = _context.Users.AsQueryable();

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(u => u.Name.Contains(search) || u.Phone.Contains(search));
        }

        if (request.Role.HasValue)
            query = query.Where(u => u.Role == request.Role.Value);

        if (request.IsActive.HasValue)
            query = query.Where(u => u.IsActive == request.IsActive.Value);

        var totalCount = await query.CountAsync(cancellationToken);
        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize, 1, 200);

        var items = await query
            .OrderByDescending(u => u.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(u => new UserSummaryResponse(
                u.Id,
                u.Name,
                u.Phone,
                u.Role.ToString(),
                u.IsActive,
                u.IsProMember,
                u.IsVerifiedLocal,
                u.KycVerificationStatus.ToString(),
                u.LastLoginAt,
                u.CreatedAt))
            .ToListAsync(cancellationToken);

        return new PagedResult<UserSummaryResponse>(items, totalCount, page, pageSize);
    }
}

public sealed record ChangeUserRoleCommand(Guid UserId, UserRole NewRole) : IRequest<Unit>;

public sealed class ChangeUserRoleHandler : IRequestHandler<ChangeUserRoleCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly IAdminActionLogger _actionLogger;
    private readonly ICurrentUserService _currentUser;

    public ChangeUserRoleHandler(IApplicationDbContext context, IAdminActionLogger actionLogger, ICurrentUserService currentUser)
    {
        _context = context;
        _actionLogger = actionLogger;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(ChangeUserRoleCommand request, CancellationToken cancellationToken)
    {
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Id == request.UserId, cancellationToken)
            ?? throw new InvalidOperationException("User not found.");

        if (_currentUser.UserId == request.UserId)
            throw new InvalidOperationException("Admins cannot change their own role.");

        var previousRole = user.Role;
        user.ChangeRole(request.NewRole);
        await _context.SaveChangesAsync(cancellationToken);

        await _actionLogger.LogAsync(
            actionType: "ChangeUserRole",
            entityType: nameof(User),
            entityId: request.UserId,
            payload: new { PreviousRole = previousRole.ToString(), NewRole = request.NewRole.ToString() },
            cancellationToken: cancellationToken);

        return Unit.Value;
    }
}

public sealed record SetUserActiveStatusCommand(Guid UserId, bool IsActive) : IRequest<Unit>;

public sealed class SetUserActiveStatusHandler : IRequestHandler<SetUserActiveStatusCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly IAdminActionLogger _actionLogger;
    private readonly ICurrentUserService _currentUser;

    public SetUserActiveStatusHandler(IApplicationDbContext context, IAdminActionLogger actionLogger, ICurrentUserService currentUser)
    {
        _context = context;
        _actionLogger = actionLogger;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(SetUserActiveStatusCommand request, CancellationToken cancellationToken)
    {
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Id == request.UserId, cancellationToken)
            ?? throw new InvalidOperationException("User not found.");

        if (!request.IsActive && _currentUser.UserId == request.UserId)
            throw new InvalidOperationException("Admins cannot deactivate their own account.");

        if (request.IsActive)
            user.Activate();
        else
            user.Deactivate();

        await _context.SaveChangesAsync(cancellationToken);

        await _actionLogger.LogAsync(
            actionType: request.IsActive ? "ActivateUser" : "DeactivateUser",
            entityType: nameof(User),
            entityId: request.UserId,
            payload: new { IsActive = request.IsActive },
            cancellationToken: cancellationToken);

        return Unit.Value;
    }
}

// === Driver Management ===

public sealed record ListDriversQuery(
    string? Search = null,
    bool? IsApproved = null,
    bool? IsOnline = null,
    bool? KycUploadedOnly = false,
    int Page = 1,
    int PageSize = 50) : IRequest<PagedResult<DriverSummaryResponse>>;

public sealed record DriverSummaryResponse(
    Guid Id,
    Guid UserId,
    string Name,
    string Phone,
    string VehicleType,
    string? VehiclePlate,
    bool IsApproved,
    bool IsOnline,
    bool IsOnRide,
    bool IsKycUploaded,
    double Rating,
    int TotalRides,
    double? Latitude,
    double? Longitude,
    DateTimeOffset? LastLocationAt,
    DateTimeOffset CreatedAt,
    string? AadhaarUrl,
    string? DrivingLicenseUrl,
    string? RcUrl,
    string? InsuranceUrl,
    string? SelfieUrl);

public sealed class ListDriversHandler : IRequestHandler<ListDriversQuery, PagedResult<DriverSummaryResponse>>
{
    private readonly IApplicationDbContext _context;

    public ListDriversHandler(IApplicationDbContext context) => _context = context;

    public async Task<PagedResult<DriverSummaryResponse>> Handle(ListDriversQuery request, CancellationToken cancellationToken)
    {
        var query = _context.Drivers.AsQueryable();

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(d => d.Name.Contains(search) || d.Phone.Contains(search));
        }

        if (request.IsApproved.HasValue)
            query = query.Where(d => d.IsApproved == request.IsApproved.Value);

        if (request.IsOnline.HasValue)
            query = query.Where(d => d.IsOnline == request.IsOnline.Value);

        if (request.KycUploadedOnly == true)
            query = query.Where(d => d.IsKycUploaded);

        var totalCount = await query.CountAsync(cancellationToken);
        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize, 1, 200);

        var items = await query
            .OrderByDescending(d => d.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(d => new DriverSummaryResponse(
                d.Id,
                d.UserId,
                d.Name,
                d.Phone,
                d.VehicleType.ToString(),
                d.VehiclePlate,
                d.IsApproved,
                d.IsOnline,
                d.IsOnRide,
                d.IsKycUploaded,
                d.Rating,
                d.TotalRides,
                d.CurrentLocation.Latitude,
                d.CurrentLocation.Longitude,
                d.LastLocationAt,
                d.CreatedAt,
                d.AadhaarUrl,
                d.DrivingLicenseUrl,
                d.RcUrl,
                d.InsuranceUrl,
                d.SelfieUrl))
            .ToListAsync(cancellationToken);

        return new PagedResult<DriverSummaryResponse>(items, totalCount, page, pageSize);
    }
}

public sealed record RejectDriverKycCommand(Guid DriverId, string? Reason = null) : IRequest<Unit>;

public sealed class RejectDriverKycHandler : IRequestHandler<RejectDriverKycCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly IAdminActionLogger _actionLogger;

    public RejectDriverKycHandler(IApplicationDbContext context, IAdminActionLogger actionLogger)
    {
        _context = context;
        _actionLogger = actionLogger;
    }

    public async Task<Unit> Handle(RejectDriverKycCommand request, CancellationToken cancellationToken)
    {
        var driver = await _context.Drivers
            .FirstOrDefaultAsync(d => d.Id == request.DriverId, cancellationToken)
            ?? throw new InvalidOperationException("Driver not found.");

        // Reset KYC upload state so the driver can re-submit.
        // We reuse the existing domain method by setting KycVerificationStatus
        // via the User entity linked to this driver.
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Id == driver.UserId, cancellationToken);

        if (user is not null)
        {
            user.RejectKyc();
        }

        await _context.SaveChangesAsync(cancellationToken);

        await _actionLogger.LogAsync(
            actionType: "RejectDriverKyc",
            entityType: nameof(Driver),
            entityId: request.DriverId,
            payload: new { Reason = request.Reason },
            cancellationToken: cancellationToken);

        return Unit.Value;
    }
}

// === Live Operations: Real SOS Alerts ===

public sealed record GetActiveSosAlertsQuery() : IRequest<IReadOnlyList<SosAlertResponse>>;

public sealed record SosAlertResponse(
    Guid Id,
    Guid RideId,
    Guid UserId,
    string UserName,
    string UserPhone,
    double Latitude,
    double Longitude,
    string Status,
    DateTimeOffset TriggeredAt,
    DateTimeOffset? ResolvedAt,
    string? Notes,
    string? VehicleType,
    string? VehiclePlate,
    string? EmergencyContactName,
    string? EmergencyContactPhone);

public sealed class GetActiveSosAlertsHandler : IRequestHandler<GetActiveSosAlertsQuery, IReadOnlyList<SosAlertResponse>>
{
    private readonly IApplicationDbContext _context;

    public GetActiveSosAlertsHandler(IApplicationDbContext context) => _context = context;

    public async Task<IReadOnlyList<SosAlertResponse>> Handle(GetActiveSosAlertsQuery request, CancellationToken cancellationToken)
    {
        // Join SOS → User for name/phone, then left-join RideRequest → Driver
        // for vehicle details and emergency contacts.
        var query = from s in _context.SosAlerts
                    where s.Status == SosStatus.Active
                    orderby s.TriggeredAt descending
                    join u in _context.Users on s.UserId equals u.Id
                    join r in _context.RideRequests on s.RideId equals r.Id into rideGroup
                    from r in rideGroup.DefaultIfEmpty()
                    join d in _context.Drivers on r.DriverId equals d.Id into driverGroup
                    from d in driverGroup.DefaultIfEmpty()
                    select new SosAlertResponse(
                        s.Id,
                        s.RideId,
                        s.UserId,
                        u.Name,
                        u.Phone,
                        s.Location.Latitude,
                        s.Location.Longitude,
                        s.Status.ToString(),
                        s.TriggeredAt,
                        s.ResolvedAt,
                        s.Notes,
                        d != null ? d.VehicleType.ToString() : null,
                        d != null ? d.VehiclePlate : null,
                        d != null ? d.EmergencyContactName : null,
                        d != null ? d.EmergencyContactPhone : null);

        return await query.Take(100).ToListAsync(cancellationToken);
    }
}

public sealed record ResolveSosAlertCommand(Guid SosAlertId, string? Notes = null) : IRequest<Unit>;

public sealed class ResolveSosAlertHandler : IRequestHandler<ResolveSosAlertCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly IAdminActionLogger _actionLogger;
    private readonly ICurrentUserService _currentUser;

    public ResolveSosAlertHandler(
        IApplicationDbContext context,
        IAdminActionLogger actionLogger,
        ICurrentUserService currentUser)
    {
        _context = context;
        _actionLogger = actionLogger;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(ResolveSosAlertCommand request, CancellationToken cancellationToken)
    {
        var alert = await _context.SosAlerts
            .FirstOrDefaultAsync(s => s.Id == request.SosAlertId, cancellationToken)
            ?? throw new InvalidOperationException("SOS alert not found.");

        var resolverId = _currentUser.UserId
            ?? throw new InvalidOperationException("Admin user ID is not available.");

        alert.Resolve(resolverId, SosStatus.Resolved, request.Notes);
        await _context.SaveChangesAsync(cancellationToken);

        await _actionLogger.LogAsync(
            actionType: "ResolveSosAlert",
            entityType: nameof(SosAlert),
            entityId: request.SosAlertId,
            payload: new { Notes = request.Notes },
            cancellationToken: cancellationToken);

        return Unit.Value;
    }
}

// === Live Operations: Active Rides ===

public sealed record GetActiveRidesQuery() : IRequest<IReadOnlyList<ActiveRideResponse>>;

public sealed record ActiveRideResponse(
    Guid Id,
    Guid UserId,
    string RiderName,
    string RiderPhone,
    Guid? DriverId,
    string? DriverName,
    string? DriverPhone,
    string Status,
    double? PickupLatitude,
    double? PickupLongitude,
    double? DropLatitude,
    double? DropLongitude,
    decimal EstimatedFare,
    string? VehicleType,
    DateTimeOffset CreatedAt);

public sealed class GetActiveRidesHandler : IRequestHandler<GetActiveRidesQuery, IReadOnlyList<ActiveRideResponse>>
{
    private readonly IApplicationDbContext _context;

    public GetActiveRidesHandler(IApplicationDbContext context) => _context = context;

    public async Task<IReadOnlyList<ActiveRideResponse>> Handle(GetActiveRidesQuery request, CancellationToken cancellationToken)
    {
        var activeStatuses = new[]
        {
            RideStatus.Requested,
            RideStatus.Searching,
            RideStatus.DriverAssigned,
            RideStatus.Accepted,
            RideStatus.ArrivedAtPickup,
            RideStatus.EnRoute
        };

        var query = from ride in _context.RideRequests
                    where activeStatuses.Contains(ride.Status)
                    join user in _context.Users on ride.UserId equals user.Id into users
                    from user in users.DefaultIfEmpty()
                    join driver in _context.Drivers on ride.DriverId equals (Guid?)driver.Id into drivers
                    from driver in drivers.DefaultIfEmpty()
                    orderby ride.CreatedAt descending
                    select new ActiveRideResponse(
                        ride.Id,
                        ride.UserId,
                        user != null ? user.Name : string.Empty,
                        user != null ? user.Phone : string.Empty,
                        ride.DriverId,
                        driver != null ? driver.Name : null,
                        driver != null ? driver.Phone : null,
                        ride.Status.ToString(),
                        (double?)ride.PickupLocation.Latitude,
                        (double?)ride.PickupLocation.Longitude,
                        (double?)ride.DropoffLocation.Latitude,
                        (double?)ride.DropoffLocation.Longitude,
                        ride.Fare,
                        ride.VehicleType.ToString(),
                        ride.CreatedAt);

        return await query.Take(100).ToListAsync(cancellationToken);
    }
}

// === Live Operations: Support Tickets ===

public sealed record GetSupportTicketsQuery(
    SupportTicketStatus? Status = null,
    int Page = 1,
    int PageSize = 50) : IRequest<PagedResult<SupportTicketResponse>>;

public sealed record SupportTicketResponse(
    Guid Id,
    Guid UserId,
    string UserName,
    string UserPhone,
    string Status,
    string Priority,
    string Source,
    string? IssueCategory,
    double? Latitude,
    double? Longitude,
    DateTimeOffset? AcknowledgedAt,
    DateTimeOffset? ResolvedAt,
    DateTimeOffset CreatedAt);

public sealed class GetSupportTicketsHandler : IRequestHandler<GetSupportTicketsQuery, PagedResult<SupportTicketResponse>>
{
    private readonly IApplicationDbContext _context;

    public GetSupportTicketsHandler(IApplicationDbContext context) => _context = context;

    public async Task<PagedResult<SupportTicketResponse>> Handle(GetSupportTicketsQuery request, CancellationToken cancellationToken)
    {
        var query = _context.SupportTickets.AsQueryable();

        if (request.Status.HasValue)
            query = query.Where(t => t.Status == request.Status.Value);

        var totalCount = await query.CountAsync(cancellationToken);
        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize, 1, 200);

        var items = await (
            from ticket in query
            orderby ticket.CreatedAt descending
            join user in _context.Users on ticket.UserId equals user.Id into users
            from user in users.DefaultIfEmpty()
            select new SupportTicketResponse(
                ticket.Id,
                ticket.UserId,
                user != null ? user.Name : string.Empty,
                user != null ? user.Phone : string.Empty,
                ticket.Status.ToString(),
                ticket.Priority.ToString(),
                ticket.Source.ToString(),
                ticket.IssueCategory,
                ticket.Latitude,
                ticket.Longitude,
                ticket.AcknowledgedAt,
                ticket.ResolvedAt,
                ticket.CreatedAt))
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return new PagedResult<SupportTicketResponse>(items, totalCount, page, pageSize);
    }
}

public sealed record ResolveSupportTicketCommand(Guid TicketId) : IRequest<Unit>;

public sealed class ResolveSupportTicketHandler : IRequestHandler<ResolveSupportTicketCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly IAdminActionLogger _actionLogger;

    public ResolveSupportTicketHandler(IApplicationDbContext context, IAdminActionLogger actionLogger)
    {
        _context = context;
        _actionLogger = actionLogger;
    }

    public async Task<Unit> Handle(ResolveSupportTicketCommand request, CancellationToken cancellationToken)
    {
        var ticket = await _context.SupportTickets
            .FirstOrDefaultAsync(t => t.Id == request.TicketId, cancellationToken)
            ?? throw new InvalidOperationException("Support ticket not found.");

        ticket.Resolve();
        await _context.SaveChangesAsync(cancellationToken);

        await _actionLogger.LogAsync(
            actionType: "ResolveSupportTicket",
            entityType: nameof(SupportTicket),
            entityId: request.TicketId,
            cancellationToken: cancellationToken);

        return Unit.Value;
    }
}

public sealed record AcknowledgeSupportTicketCommand(Guid TicketId) : IRequest<Unit>;

public sealed class AcknowledgeSupportTicketHandler : IRequestHandler<AcknowledgeSupportTicketCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly IAdminActionLogger _actionLogger;

    public AcknowledgeSupportTicketHandler(IApplicationDbContext context, IAdminActionLogger actionLogger)
    {
        _context = context;
        _actionLogger = actionLogger;
    }

    public async Task<Unit> Handle(AcknowledgeSupportTicketCommand request, CancellationToken cancellationToken)
    {
        var ticket = await _context.SupportTickets
            .FirstOrDefaultAsync(t => t.Id == request.TicketId, cancellationToken)
            ?? throw new InvalidOperationException("Support ticket not found.");

        // Transition from Open to InProgress to signal acknowledgement
        if (ticket.Status == SupportTicketStatus.Open)
        {
            ticket.Acknowledge();
            await _context.SaveChangesAsync(cancellationToken);

            await _actionLogger.LogAsync(
                actionType: "AcknowledgeSupportTicket",
                entityType: nameof(SupportTicket),
                entityId: request.TicketId,
                cancellationToken: cancellationToken);
        }

        return Unit.Value;
    }
}

// === Dashboard Stats ===

public sealed record GetDashboardStatsQuery() : IRequest<DashboardStatsResponse>;

public sealed record DashboardStatsResponse(
    int TotalUsers,
    int ActiveUsers,
    int TotalDrivers,
    int ApprovedDrivers,
    int OnlineDrivers,
    int ActiveRides,
    int ActiveSosAlerts,
    int OpenSupportTickets,
    int TotalVendors,
    int ApprovedVendors,
    int TotalVenues);

public sealed class GetDashboardStatsHandler : IRequestHandler<GetDashboardStatsQuery, DashboardStatsResponse>
{
    private readonly IApplicationDbContext _context;

    public GetDashboardStatsHandler(IApplicationDbContext context) => _context = context;

    public async Task<DashboardStatsResponse> Handle(GetDashboardStatsQuery request, CancellationToken cancellationToken)
    {
        var activeRideStatuses = new[]
        {
            RideStatus.Requested,
            RideStatus.Searching,
            RideStatus.DriverAssigned,
            RideStatus.Accepted,
            RideStatus.ArrivedAtPickup,
            RideStatus.EnRoute
        };

        var totalUsers = await _context.Users.CountAsync(cancellationToken);
        var activeUsers = await _context.Users.CountAsync(u => u.IsActive, cancellationToken);
        var totalDrivers = await _context.Drivers.CountAsync(cancellationToken);
        var approvedDrivers = await _context.Drivers.CountAsync(d => d.IsApproved, cancellationToken);
        var onlineDrivers = await _context.Drivers.CountAsync(d => d.IsOnline, cancellationToken);
        var activeRides = await _context.RideRequests.CountAsync(r => activeRideStatuses.Contains(r.Status), cancellationToken);
        var activeSosAlerts = await _context.SosAlerts.CountAsync(s => s.Status == SosStatus.Active, cancellationToken);
        var openTickets = await _context.SupportTickets.CountAsync(t => t.Status == SupportTicketStatus.Open || t.Status == SupportTicketStatus.InProgress, cancellationToken);
        var totalVendors = await _context.Vendors.CountAsync(cancellationToken);
        var approvedVendors = await _context.Vendors.CountAsync(v => v.IsApproved, cancellationToken);
        var totalVenues = await _context.Venues.CountAsync(cancellationToken);

        return new DashboardStatsResponse(
            totalUsers, activeUsers, totalDrivers, approvedDrivers, onlineDrivers,
            activeRides, activeSosAlerts, openTickets, totalVendors, approvedVendors, totalVenues);
    }
}

// === Vendor Approval ===

public sealed record ApproveVendorCommand(Guid VendorId) : IRequest<Unit>;

public sealed class ApproveVendorHandler : IRequestHandler<ApproveVendorCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly IAdminActionLogger _actionLogger;

    public ApproveVendorHandler(IApplicationDbContext context, IAdminActionLogger actionLogger)
    {
        _context = context;
        _actionLogger = actionLogger;
    }

    public async Task<Unit> Handle(ApproveVendorCommand request, CancellationToken cancellationToken)
    {
        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.Id == request.VendorId, cancellationToken)
            ?? throw new InvalidOperationException("Vendor not found.");

        vendor.Approve();
        await _context.SaveChangesAsync(cancellationToken);

        await _actionLogger.LogAsync(
            actionType: "ApproveVendor",
            entityType: nameof(Vendor),
            entityId: request.VendorId,
            cancellationToken: cancellationToken);

        return Unit.Value;
    }
}

public sealed record RejectVendorCommand(Guid VendorId, string? Reason = null) : IRequest<Unit>;

public sealed class RejectVendorHandler : IRequestHandler<RejectVendorCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly IAdminActionLogger _actionLogger;

    public RejectVendorHandler(IApplicationDbContext context, IAdminActionLogger actionLogger)
    {
        _context = context;
        _actionLogger = actionLogger;
    }

    public async Task<Unit> Handle(RejectVendorCommand request, CancellationToken cancellationToken)
    {
        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.Id == request.VendorId, cancellationToken)
            ?? throw new InvalidOperationException("Vendor not found.");

        vendor.Deactivate();
        await _context.SaveChangesAsync(cancellationToken);

        await _actionLogger.LogAsync(
            actionType: "RejectVendor",
            entityType: nameof(Vendor),
            entityId: request.VendorId,
            payload: new { Reason = request.Reason },
            cancellationToken: cancellationToken);

        return Unit.Value;
    }
}

// === Admin Action Logs ===

public sealed record GetAdminActionLogsQuery(
    string? ActionType = null,
    Guid? AdminUserId = null,
    int Page = 1,
    int PageSize = 50) : IRequest<PagedResult<AdminActionLogResponse>>;

public sealed record AdminActionLogResponse(
    Guid Id,
    Guid AdminUserId,
    string ActionType,
    string? EntityType,
    Guid? EntityId,
    string? Payload,
    string? IpAddress,
    DateTimeOffset CreatedAt);

public sealed class GetAdminActionLogsHandler : IRequestHandler<GetAdminActionLogsQuery, PagedResult<AdminActionLogResponse>>
{
    private readonly IApplicationDbContext _context;

    public GetAdminActionLogsHandler(IApplicationDbContext context) => _context = context;

    public async Task<PagedResult<AdminActionLogResponse>> Handle(GetAdminActionLogsQuery request, CancellationToken cancellationToken)
    {
        var query = _context.AdminActionLogs.AsQueryable();

        if (!string.IsNullOrWhiteSpace(request.ActionType))
            query = query.Where(l => l.ActionType == request.ActionType);

        if (request.AdminUserId.HasValue)
            query = query.Where(l => l.AdminUserId == request.AdminUserId.Value);

        var totalCount = await query.CountAsync(cancellationToken);
        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize, 1, 200);

        var items = await query
            .OrderByDescending(l => l.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(l => new AdminActionLogResponse(
                l.Id,
                l.AdminUserId,
                l.ActionType,
                l.EntityType,
                l.EntityId,
                l.Payload,
                l.IpAddress,
                l.CreatedAt))
            .ToListAsync(cancellationToken);

        return new PagedResult<AdminActionLogResponse>(items, totalCount, page, pageSize);
    }
}

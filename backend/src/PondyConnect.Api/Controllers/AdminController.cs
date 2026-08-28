namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Api.Hubs;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Admin;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]
public sealed class AdminController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IHubContext<AdminHub> _hubContext;
    private readonly IApplicationDbContext _dbContext;

    public AdminController(IMediator mediator, IHubContext<AdminHub> hubContext, IApplicationDbContext dbContext)
    {
        _mediator = mediator;
        _hubContext = hubContext;
        _dbContext = dbContext;
    }

    [HttpPost("venues/{venueId:guid}/force-soldout")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ForceSoldOut(Guid venueId, [FromQuery] bool soldOut, CancellationToken ct)
    {
        try
        {
            await _mediator.Send(new ForceSoldOutCommand(venueId, soldOut), ct);
            await _hubContext.Clients.Group("admins").SendAsync("VenueStatusChanged", new { VenueId = venueId, SoldOut = soldOut }, ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    [HttpGet("surge")]
    [ProducesResponseType(typeof(SurgeModeResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public ActionResult<SurgeModeResponse> GetCurrentSurge()
    {
        var mode = SurgeState.CurrentMode;
        var multiplier = SurgeState.FeeMultiplier;
        var label = mode switch
        {
            SurgeMode.Normal => "Normal Operations",
            SurgeMode.Monsoon => "Monsoon Mode (+20% fees)",
            SurgeMode.FestivalSurge => "Festival Surge (+20% fees)",
            _ => "Normal"
        };
        return Ok(new SurgeModeResponse(mode, multiplier, label));
    }

    [HttpPost("surge")]
    [ProducesResponseType(typeof(SurgeModeResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<SurgeModeResponse>> SetSurgeMode([FromBody] SetSurgeModeRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new SetSurgeModeCommand(request.Mode), ct);
        await _hubContext.Clients.Group("admins").SendAsync("SurgeModeChanged", result, ct);
        return Ok(result);
    }

    [HttpGet("sos-events")]
    [ProducesResponseType(typeof(IReadOnlyList<SosEventResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<SosEventResponse>>> GetSosEvents(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetSosEventsQuery(), ct);
        return Ok(result);
    }

    [HttpPost("approve-driver/{driverId:guid}")]
    [HttpPost("drivers/{driverId:guid}/approve")]
    [ProducesResponseType(typeof(ApproveDriverResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ApproveDriverResponse>> ApproveDriver(Guid driverId, CancellationToken ct)
    {
        var result = await _mediator.Send(new ApproveDriverCommand(driverId), ct);
        if (!result.Success && string.IsNullOrEmpty(result.DriverName))
            return NotFound(new { Message = result.Message });
        return Ok(result);
    }

    /// <summary>
    /// Resumes dispatch for a driver who was auto-paused due to low ratings.
    /// The admin should review the low-rating feedback before resuming.
    /// </summary>
    [HttpPost("drivers/{driverId:guid}/resume-dispatch")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ResumeDriverDispatch(Guid driverId, CancellationToken ct)
    {
        var driver = await _dbContext.Drivers.FirstOrDefaultAsync(d => d.Id == driverId, ct);
        if (driver is null)
            return NotFound(new { Message = "Driver not found." });

        driver.ResumeFromReview();
        await _dbContext.SaveChangesAsync(ct);
        return Ok(new { Message = "Driver dispatch resumed." });
    }

    // === Vendor Onboarding ===

    [HttpGet("vendors")]
    [HttpGet("vendors/pending")]
    [ProducesResponseType(typeof(IReadOnlyList<VendorSummaryResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<VendorSummaryResponse>>> ListVendors(
        [FromQuery] bool? isApproved = null,
        [FromQuery] string? category = null,
        CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListAllVendorsQuery(isApproved, category), ct);
        return Ok(result);
    }

    [HttpPost("vendors")]
    [ProducesResponseType(typeof(OnboardVendorResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<OnboardVendorResponse>> OnboardVendor([FromBody] OnboardVendorRequest request, CancellationToken ct)
    {
        try
        {
            var result = await _mediator.Send(new OnboardVendorCommand(
                request.Name,
                request.ContactPhone,
                request.Category,
                request.CuisineType,
                request.Description,
                request.DeliveryFee,
                request.PrepTimeMinutes), ct);
            return CreatedAtAction(nameof(ListVendors), new { id = result.VendorId }, result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    [HttpPost("vendors/{vendorId:guid}/approve")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ApproveVendor(Guid vendorId, CancellationToken ct)
    {
        try
        {
            await _mediator.Send(new ApproveVendorCommand(vendorId), ct);
            await _hubContext.Clients.Group("admins").SendAsync("VendorApproved", new { VendorId = vendorId }, ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    [HttpPost("vendors/{vendorId:guid}/reject")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RejectVendor(Guid vendorId, [FromBody] RejectVendorRequest? request, CancellationToken ct)
    {
        try
        {
            await _mediator.Send(new RejectVendorCommand(vendorId, request?.Reason), ct);
            await _hubContext.Clients.Group("admins").SendAsync("VendorRejected", new { VendorId = vendorId }, ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    // === Phase 2: Dashboard Stats ===

    [HttpGet("dashboard-stats")]
    [HttpGet("analytics")]
    [ProducesResponseType(typeof(DashboardStatsResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<DashboardStatsResponse>> GetDashboardStats(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetDashboardStatsQuery(), ct);
        return Ok(result);
    }

    // === Phase 2: User Management ===

    [HttpGet("users")]
    [ProducesResponseType(typeof(PagedResult<UserSummaryResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<PagedResult<UserSummaryResponse>>> ListUsers(
        [FromQuery] string? search = null,
        [FromQuery] UserRole? role = null,
        [FromQuery] bool? isActive = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListUsersQuery(search, role, isActive, page, pageSize), ct);
        return Ok(result);
    }

    [HttpPost("users/{userId:guid}/role")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ChangeUserRole(Guid userId, [FromBody] ChangeUserRoleRequest request, CancellationToken ct)
    {
        try
        {
            await _mediator.Send(new ChangeUserRoleCommand(userId, request.NewRole), ct);
            await _hubContext.Clients.Group("admins").SendAsync("UserRoleChanged", new { UserId = userId, Role = request.NewRole.ToString() }, ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    [HttpPost("users/{userId:guid}/active-status")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SetUserActiveStatus(Guid userId, [FromQuery] bool isActive, CancellationToken ct)
    {
        try
        {
            await _mediator.Send(new SetUserActiveStatusCommand(userId, isActive), ct);
            await _hubContext.Clients.Group("admins").SendAsync("UserStatusChanged", new { UserId = userId, IsActive = isActive }, ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    // === Phase 2: Driver Management ===

    [HttpGet("drivers")]
    [HttpGet("drivers/pending")]
    [ProducesResponseType(typeof(PagedResult<DriverSummaryResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<PagedResult<DriverSummaryResponse>>> ListDrivers(
        [FromQuery] string? search = null,
        [FromQuery] bool? isApproved = null,
        [FromQuery] bool? isOnline = null,
        [FromQuery] bool kycUploadedOnly = false,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListDriversQuery(search, isApproved, isOnline, kycUploadedOnly, page, pageSize), ct);
        return Ok(result);
    }

    [HttpPost("drivers/{driverId:guid}/reject-kyc")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RejectDriverKyc(Guid driverId, [FromBody] RejectKycRequest? request, CancellationToken ct)
    {
        try
        {
            await _mediator.Send(new RejectDriverKycCommand(driverId, request?.Reason), ct);
            await _hubContext.Clients.Group("admins").SendAsync("DriverKycRejected", new { DriverId = driverId }, ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    // === Flow 6: KYC Review & Approval ===

    [HttpPost("kyc/{driverId:guid}/approve")]
    [ProducesResponseType(typeof(ApproveKycResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ApproveKycResponse>> ApproveKyc(Guid driverId, CancellationToken ct)
    {
        var result = await _mediator.Send(new ApproveKycCommand(driverId), ct);
        if (!result.Success && string.IsNullOrEmpty(result.DriverName))
            return NotFound(new { Message = result.Message });

        if (!result.Success)
            return BadRequest(new { Message = result.Message });

        await _hubContext.Clients.Group("admins").SendAsync("DriverApproved", new { DriverId = driverId }, ct);
        return Ok(result);
    }

    // === Phase 2: Live Operations - Real SOS ===

    [HttpGet("sos-alerts")]
    [ProducesResponseType(typeof(IReadOnlyList<SosAlertResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<SosAlertResponse>>> GetActiveSosAlerts(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetActiveSosAlertsQuery(), ct);
        return Ok(result);
    }

    [HttpPost("sos-alerts/{sosAlertId:guid}/resolve")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ResolveSosAlert(Guid sosAlertId, [FromBody] ResolveSosRequest? request, CancellationToken ct)
    {
        try
        {
            await _mediator.Send(new ResolveSosAlertCommand(sosAlertId, request?.Notes), ct);
            await _hubContext.Clients.Group("admins").SendAsync("SosAlertResolved", new { SosAlertId = sosAlertId }, ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    // === Phase 2: Live Operations - Active Rides ===

    [HttpGet("active-rides")]
    [ProducesResponseType(typeof(IReadOnlyList<ActiveRideResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<ActiveRideResponse>>> GetActiveRides(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetActiveRidesQuery(), ct);
        return Ok(result);
    }

    /// <summary>
    /// Returns in-flight food/essentials deliveries (Assigned or InProgress)
    /// with the assigned driver's last known location for the admin live ops map.
    /// </summary>
    [HttpGet("active-deliveries")]
    [ProducesResponseType(typeof(IReadOnlyList<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<object>>> GetActiveDeliveries(CancellationToken ct)
    {
        var deliveries = await (
            from t in _dbContext.DispatchTasks.AsNoTracking()
            where t.TaskType == DispatchTaskType.FoodDelivery
                && (t.Status == DispatchTaskStatus.Assigned || t.Status == DispatchTaskStatus.InProgress)
            join d in _dbContext.Drivers.AsNoTracking() on t.DriverId equals d.Id into dJoin
            from d in dJoin.DefaultIfEmpty()
            select new
            {
                t.Id,
                TaskType = t.TaskType.ToString(),
                Status = t.Status.ToString(),
                t.PickupAddress,
                t.DropoffAddress,
                DriverName = d != null ? d.Name : null,
                Latitude = d != null ? d.CurrentLocation.Latitude : (double?)null,
                Longitude = d != null ? d.CurrentLocation.Longitude : (double?)null,
            }).ToListAsync(ct);

        return Ok(deliveries);
    }

    // === Phase 2: Support Tickets ===

    [HttpGet("support-tickets")]
    [ProducesResponseType(typeof(PagedResult<SupportTicketResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<PagedResult<SupportTicketResponse>>> GetSupportTickets(
        [FromQuery] SupportTicketStatus? status = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken ct = default)
    {
        var result = await _mediator.Send(new GetSupportTicketsQuery(status, page, pageSize), ct);
        return Ok(result);
    }

    [HttpPost("support-tickets/{ticketId:guid}/resolve")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ResolveSupportTicket(Guid ticketId, CancellationToken ct)
    {
        try
        {
            await _mediator.Send(new ResolveSupportTicketCommand(ticketId), ct);
            await _hubContext.Clients.Group("admins").SendAsync("SupportTicketResolved", new { TicketId = ticketId }, ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    [HttpPost("support-tickets/{ticketId:guid}/acknowledge")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> AcknowledgeSupportTicket(Guid ticketId, CancellationToken ct)
    {
        try
        {
            await _mediator.Send(new AcknowledgeSupportTicketCommand(ticketId), ct);
            await _hubContext.Clients.Group("admins").SendAsync("SupportTicketAcknowledged", new { TicketId = ticketId }, ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    [HttpGet("support-tickets/critical")]
    [ProducesResponseType(typeof(IReadOnlyList<SupportTicketResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<SupportTicketResponse>>> GetCriticalTickets(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetSupportTicketsQuery(SupportTicketStatus.Escalated, 1, 50), ct);
        return Ok(result.Items);
    }

    // === Flow 6: Dispute Refunds ===

    [HttpPost("tickets/{ticketId:guid}/refund")]
    [ProducesResponseType(typeof(RefundTicketResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<RefundTicketResponse>> RefundTicket(
        Guid ticketId,
        [FromBody] RefundTicketRequest request,
        CancellationToken ct)
    {
        try
        {
            var result = await _mediator.Send(new RefundTicketCommand(ticketId, request.Amount, request.FullRefund), ct);
            await _hubContext.Clients.Group("admins").SendAsync("TicketRefunded", new { TicketId = ticketId, result.RefundAmount }, ct);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    // === Phase 2: Driver Withdrawals ===

    [HttpGet("withdrawals")]
    [ProducesResponseType(typeof(IReadOnlyList<DriverWithdrawalResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<DriverWithdrawalResponse>>> ListWithdrawals(
        [FromQuery] DriverWithdrawalStatus? status = null,
        CancellationToken ct = default)
    {
        var query = _dbContext.DriverWithdrawals.AsNoTracking();

        if (status is not null)
            query = query.Where(w => w.Status == status);

        var items = await query
            .OrderByDescending(w => w.RequestedAt)
            .Select(w => new DriverWithdrawalResponse(
                w.Id,
                w.DriverId,
                w.WalletId,
                w.Amount,
                w.Status.ToString(),
                w.BankAccountNumber,
                w.UpiId,
                w.RequestedAt,
                w.ProcessedAt,
                w.AdminNote))
            .ToListAsync(ct);

        return Ok(items);
    }

    [HttpPost("withdrawals/{id:guid}/approve")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> ApproveWithdrawal(Guid id, CancellationToken ct)
    {
        var withdrawal = await _dbContext.DriverWithdrawals
            .FirstOrDefaultAsync(w => w.Id == id, ct);

        if (withdrawal is null)
            return NotFound(new { Message = "Withdrawal not found." });

        try
        {
            withdrawal.Approve();
            await _dbContext.SaveChangesAsync(ct);
            return Ok(new { Message = "Withdrawal approved and marked for processing." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    [HttpPost("withdrawals/{id:guid}/reject")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> RejectWithdrawal(
        Guid id,
        [FromBody] RejectWithdrawalRequest? request,
        CancellationToken ct)
    {
        var withdrawal = await _dbContext.DriverWithdrawals
            .FirstOrDefaultAsync(w => w.Id == id, ct);

        if (withdrawal is null)
            return NotFound(new { Message = "Withdrawal not found." });

        try
        {
            withdrawal.Reject(request?.AdminNote);

            // Refund the withheld wallet balance by re-crediting it.
            var wallet = await _dbContext.DriverWallets
                .FirstOrDefaultAsync(w => w.Id == withdrawal.WalletId, ct);

            if (wallet is not null)
            {
                wallet.Credit(withdrawal.Amount);
                _dbContext.DriverWalletTransactions.Add(DriverWalletTransaction.Create(
                    wallet.Id,
                    DriverWalletTransactionType.Adjustment,
                    withdrawal.Amount,
                    $"Reversal of rejected withdrawal {id}",
                    id.ToString()));
            }

            await _dbContext.SaveChangesAsync(ct);
            return Ok(new { Message = "Withdrawal rejected and amount refunded to wallet." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    // === Phase 2: Admin Action Logs ===

    [HttpGet("action-logs")]
    [ProducesResponseType(typeof(PagedResult<AdminActionLogResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<PagedResult<AdminActionLogResponse>>> GetActionLogs(
        [FromQuery] string? actionType = null,
        [FromQuery] Guid? adminUserId = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken ct = default)
    {
        var result = await _mediator.Send(new GetAdminActionLogsQuery(actionType, adminUserId, page, pageSize), ct);
        return Ok(result);
    }
}

public sealed record SetSurgeModeRequest(SurgeMode Mode);

public sealed record OnboardVendorRequest(
    string Name,
    string ContactPhone,
    string Category,
    string? CuisineType = null,
    string? Description = null,
    decimal? DeliveryFee = null,
    int? PrepTimeMinutes = null);

public sealed record ChangeUserRoleRequest(UserRole NewRole);

public sealed record RejectKycRequest(string? Reason = null);

public sealed record ResolveSosRequest(string? Notes = null);
public sealed record RejectVendorRequest(string? Reason = null);

public sealed record DriverWithdrawalResponse(
    Guid Id,
    Guid DriverId,
    Guid WalletId,
    decimal Amount,
    string Status,
    string? BankAccountNumber,
    string? UpiId,
    DateTimeOffset RequestedAt,
    DateTimeOffset? ProcessedAt,
    string? AdminNote);

public sealed record RejectWithdrawalRequest(string? AdminNote = null);
public sealed record RefundTicketRequest(decimal Amount, bool FullRefund);

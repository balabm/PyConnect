namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

/// <summary>
/// Genie Engine — custom errand requests. A consumer types a free-text
/// errand (e.g. "Pick up my laundry from Auroville") and an auth-hold is
/// placed on their card. A captain accepts, starts progress, and completes
/// the errand with the actual cost.
///
/// Payment flow:
/// 1. Create errand → backend creates a Razorpay auth-hold order (capture: false)
/// 2. Consumer completes Razorpay checkout → frontend sends paymentId back
/// 3. Captain completes errand with actual cost → backend captures the full
///    auth-hold and refunds the difference (Razorpay does not support partial
///    capture, so we capture full + refund the excess)
/// 4. Cancel errand → backend releases the auth-hold
/// </summary>
[ApiController]
[Route("api/genie")]
[Authorize]
public sealed class GenieController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IPaymentGateway _paymentGateway;
    private readonly ILogger<GenieController> _logger;

    public GenieController(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IPaymentGateway paymentGateway,
        ILogger<GenieController> logger)
    {
        _context = context;
        _currentUser = currentUser;
        _paymentGateway = paymentGateway;
        _logger = logger;
    }

    // ── Consumer: Create errand ──

    /// <summary>
    /// Creates a new Genie errand request and places an auth-hold on the
    /// consumer's card for the captain to fulfil.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(GenieErrandDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<GenieErrandDto>> CreateErrand(
        [FromBody] CreateGenieErrandRequest request, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var authHold = request.AuthHoldAmount ?? request.EstimatedCost;

        GenieErrand errand;
        try
        {
            errand = GenieErrand.Create(
                userId.Value,
                request.Description,
                request.EstimatedCost,
                authHold,
                request.PickupAddress,
                request.PickupLat,
                request.PickupLng,
                request.DropoffAddress,
                request.DropoffLat,
                request.DropoffLng);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }

        _context.GenieErrands.Add(errand);
        await _context.SaveChangesAsync(ct);

        // Create a Razorpay auth-hold order (capture: false) so the consumer's
        // card is authorized but not charged until the captain completes the errand.
        try
        {
            var receipt = $"genie-{errand.Id.ToString().Substring(0, 8)}";
            var order = await _paymentGateway.CreateOrderAsync(
                authHold, "INR", receipt, capture: false, cancellationToken: ct);

            errand.SetRazorpayOrderId(order.OrderId);
            await _context.SaveChangesAsync(ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create Razorpay auth-hold for errand {ErrandId}", errand.Id);
            // Don't fail the request — the errand is created, payment can be retried
        }

        return CreatedAtAction(nameof(GetById), new { id = errand.Id }, ToDto(errand, isOwner: true));
    }

    // ── Consumer: Confirm payment after Razorpay checkout ──

    /// <summary>
    /// Confirms the Razorpay payment for an errand auth-hold.
    /// Called by the frontend after the consumer completes Razorpay checkout.
    /// Stores the payment ID so it can be captured when the captain completes the errand.
    /// </summary>
    [HttpPost("{id:guid}/confirm-payment")]
    [ProducesResponseType(typeof(GenieErrandDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<GenieErrandDto>> ConfirmPayment(
        Guid id, [FromBody] ConfirmGeniePaymentRequest request, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var errand = await _context.GenieErrands.FirstOrDefaultAsync(e => e.Id == id, ct);
        if (errand is null)
            return NotFound(new { Message = "Errand not found." });

        if (errand.UserId != userId.Value)
            return Unauthorized(new { Message = "Only the owner can confirm payment." });

        errand.SetRazorpayPaymentId(request.RazorpayPaymentId);
        await _context.SaveChangesAsync(ct);

        return Ok(ToDto(errand, isOwner: true));
    }

    // ── Consumer: Cancel errand ──

    /// <summary>
    /// Cancels a draft or posted errand. Only the owner can cancel.
    /// </summary>
    [HttpPost("{id:guid}/cancel")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CancelErrand(Guid id, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var errand = await _context.GenieErrands.FirstOrDefaultAsync(e => e.Id == id, ct);
        if (errand is null)
            return NotFound(new { Message = "Errand not found." });

        if (errand.UserId != userId.Value)
            return Unauthorized(new { Message = "Only the owner can cancel this errand." });

        try
        {
            errand.Cancel();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }

        // Release the Razorpay auth-hold if one was created
        if (!string.IsNullOrEmpty(errand.RazorpayPaymentId))
        {
            try
            {
                await _paymentGateway.ReleasePaymentAsync(errand.RazorpayPaymentId, ct);
                _logger.LogInformation("Released auth-hold for cancelled errand {ErrandId}", errand.Id);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to release auth-hold for errand {ErrandId}", errand.Id);
            }
        }

        await _context.SaveChangesAsync(ct);
        return Ok(new { Message = "Errand cancelled. Any held funds will be released." });
    }

    // ── Consumer: List my errands ──

    /// <summary>
    /// Lists all errands created by the authenticated consumer.
    /// </summary>
    [HttpGet("my-errands")]
    [ProducesResponseType(typeof(IReadOnlyList<GenieErrandDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<GenieErrandDto>>> MyErrands(CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var errands = await _context.GenieErrands.AsNoTracking()
            .Where(e => e.UserId == userId.Value)
            .OrderByDescending(e => e.CreatedAt)
            .ToListAsync(ct);

        var dtos = errands.Select(e => ToDto(e, isOwner: true)).ToList();
        return Ok(dtos);
    }

    // ── Consumer / Captain: Get by id ──

    /// <summary>
    /// Gets an errand by id. Only the owner or the assigned captain can
    /// view the details.
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(GenieErrandDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<GenieErrandDto>> GetById(Guid id, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var errand = await _context.GenieErrands.AsNoTracking()
            .FirstOrDefaultAsync(e => e.Id == id, ct);
        if (errand is null)
            return NotFound(new { Message = "Errand not found." });

        var isOwner = errand.UserId == userId.Value;
        var isAssignedCaptain = errand.CaptainId.HasValue
            && await _context.Drivers.AsNoTracking()
                .AnyAsync(d => d.Id == errand.CaptainId.Value && d.UserId == userId.Value, ct);

        if (!isOwner && !isAssignedCaptain)
            return Unauthorized(new { Message = "Only the owner or assigned captain can view this errand." });

        return Ok(ToDto(errand, isOwner));
    }

    // ── Captain: Accept errand ──

    /// <summary>
    /// Captain accepts a posted errand.
    /// </summary>
    [HttpPost("{id:guid}/accept")]
    [Authorize(Roles = "Driver")]
    [ProducesResponseType(typeof(GenieErrandDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<GenieErrandDto>> AcceptErrand(Guid id, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var captainId = await _context.Drivers.AsNoTracking()
            .Where(d => d.UserId == userId.Value && d.IsApproved)
            .Select(d => d.Id)
            .FirstOrDefaultAsync(ct);
        if (captainId == Guid.Empty)
            return NotFound(new { Message = "Captain profile not found." });

        var errand = await _context.GenieErrands.FirstOrDefaultAsync(e => e.Id == id, ct);
        if (errand is null)
            return NotFound(new { Message = "Errand not found." });

        try
        {
            errand.Accept(captainId);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }

        await _context.SaveChangesAsync(ct);
        return Ok(ToDto(errand, isOwner: false));
    }

    // ── Captain: Complete errand ──

    /// <summary>
    /// Captain completes the errand with the actual cost, captured from
    /// the auth-hold.
    /// </summary>
    [HttpPost("{id:guid}/complete")]
    [Authorize(Roles = "Driver")]
    [ProducesResponseType(typeof(GenieErrandDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<GenieErrandDto>> CompleteErrand(
        Guid id, [FromBody] CompleteGenieErrandRequest request, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var errand = await _context.GenieErrands.FirstOrDefaultAsync(e => e.Id == id, ct);
        if (errand is null)
            return NotFound(new { Message = "Errand not found." });

        // Only the assigned captain can complete
        if (!errand.CaptainId.HasValue)
            return BadRequest(new { Message = "Errand has not been accepted by a captain." });

        var isAssigned = await _context.Drivers.AsNoTracking()
            .AnyAsync(d => d.Id == errand.CaptainId.Value && d.UserId == userId.Value, ct);
        if (!isAssigned)
            return Unauthorized(new { Message = "Only the assigned captain can complete this errand." });

        // Auto-start progress if still in Accepted state
        if (errand.Status == Domain.Enums.GenieErrandStatus.Accepted)
        {
            try
            {
                errand.StartProgress();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
        }

        try
        {
            errand.Complete(request.ActualCost, request.RazorpayOrderId, request.RazorpayPaymentId);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }

        // Capture the auth-hold and refund the difference.
        // Razorpay does not support partial capture, so we capture the full
        // auth-hold amount and then refund the excess (auth-hold - actual cost).
        var paymentId = request.RazorpayPaymentId ?? errand.RazorpayPaymentId;
        if (!string.IsNullOrEmpty(paymentId))
        {
            try
            {
                // Capture the full auth-hold amount
                await _paymentGateway.CapturePaymentAsync(paymentId, errand.AuthHoldAmount, ct);
                _logger.LogInformation("Captured auth-hold of {Amount} for errand {ErrandId}", errand.AuthHoldAmount, errand.Id);

                // Refund the difference between auth-hold and actual cost
                var refundAmount = errand.AuthHoldAmount - request.ActualCost;
                if (refundAmount > 0)
                {
                    await _paymentGateway.RefundAsync(
                        paymentId, refundAmount,
                        $"Genie errand refund — actual cost was less than auth-hold", ct);
                    _logger.LogInformation("Refunded {Amount} excess for errand {ErrandId}", refundAmount, errand.Id);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Payment capture/refund failed for errand {ErrandId}", errand.Id);
                // Don't fail the completion — the errand is done, payment can be reconciled
            }
        }

        await _context.SaveChangesAsync(ct);
        return Ok(ToDto(errand, isOwner: false));
    }

    private static GenieErrandDto ToDto(GenieErrand e, bool isOwner) => new(
        e.Id,
        e.Description,
        e.PickupAddress,
        e.PickupLat,
        e.PickupLng,
        e.DropoffAddress,
        e.DropoffLat,
        e.DropoffLng,
        e.EstimatedCost,
        e.AuthHoldAmount,
        e.Status.ToString(),
        e.CaptainId,
        e.ActualCost,
        e.RazorpayOrderId,
        e.RazorpayPaymentId,
        e.CreatedAt,
        e.UpdatedAt,
        isOwner);
}

// ── Request / Response DTOs ──

public sealed record CreateGenieErrandRequest(
    string Description,
    decimal EstimatedCost,
    decimal? AuthHoldAmount = null,
    string? PickupAddress = null,
    double? PickupLat = null,
    double? PickupLng = null,
    string? DropoffAddress = null,
    double? DropoffLat = null,
    double? DropoffLng = null);

public sealed record CompleteGenieErrandRequest(
    decimal ActualCost,
    string? RazorpayOrderId = null,
    string? RazorpayPaymentId = null);

public sealed record ConfirmGeniePaymentRequest(
    string RazorpayPaymentId);

public sealed record GenieErrandDto(
    Guid Id,
    string Description,
    string? PickupAddress,
    double? PickupLat,
    double? PickupLng,
    string? DropoffAddress,
    double? DropoffLat,
    double? DropoffLng,
    decimal EstimatedCost,
    decimal AuthHoldAmount,
    string Status,
    Guid? CaptainId,
    decimal? ActualCost,
    string? RazorpayOrderId,
    string? RazorpayPaymentId,
    DateTimeOffset CreatedAt,
    DateTimeOffset? UpdatedAt,
    bool IsOwner);

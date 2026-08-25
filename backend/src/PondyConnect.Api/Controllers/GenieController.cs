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
/// </summary>
[ApiController]
[Route("api/genie")]
[Authorize]
public sealed class GenieController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GenieController(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
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

        return CreatedAtAction(nameof(GetById), new { id = errand.Id }, ToDto(errand, isOwner: true));
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

        await _context.SaveChangesAsync(ct);
        return Ok(new { Message = "Errand cancelled." });
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

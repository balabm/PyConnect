namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.DineIn;
using PondyConnect.Domain.Enums;

/// <summary>
/// Dine-in QR ordering endpoints.
/// Customers scan a QR code at their table to open a session,
/// order from the menu, and pay via UPI — bypassing captain dispatch.
/// </summary>
[ApiController]
[Route("api/dine-in")]
[Authorize]
public sealed class DineInController : ControllerBase
{
    private readonly DineInService _dineInService;
    private readonly ICurrentUserService _currentUser;

    public DineInController(DineInService dineInService, ICurrentUserService currentUser)
    {
        _dineInService = dineInService;
        _currentUser = currentUser;
    }

    /// <summary>
    /// Scans a table QR code. Opens a new session if no active session exists,
    /// or returns the existing session for "add to order" flow.
    /// </summary>
    [HttpPost("scan")]
    [ProducesResponseType(typeof(ScanResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<ScanResponse>> ScanTable(
        [FromBody] ScanTableRequest request,
        CancellationToken ct)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException();

        var existing = await _dineInService.GetActiveSessionAsync(request.VenueId, request.TableId, ct);

        if (existing is not null)
        {
            // Active session — "add to order" flow
            return Ok(new ScanResponse(
                existing.Id,
                existing.TableId,
                existing.VendorId,
                existing.RootOrderId,
                IsAddToOrder: true,
                TotalSettled: existing.TotalSettled));
        }

        // New session
        var session = await _dineInService.OpenSessionAsync(
            request.VenueId,
            request.VendorId,
            request.TableId,
            userId,
            ct);

        return Ok(new ScanResponse(
            session.Id,
            session.TableId,
            session.VendorId,
            RootOrderId: null,
            IsAddToOrder: false,
            TotalSettled: 0m));
    }

    /// <summary>
    /// Closes a dine-in session when the bill is settled.
    /// </summary>
    [HttpPost("{sessionId}/close")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> CloseSession(Guid sessionId, CancellationToken ct)
    {
        await _dineInService.CloseSessionAsync(sessionId, ct);
        return NoContent();
    }

    /// <summary>
    /// Gets the active session for a table, if any.
    /// </summary>
    [HttpGet("active")]
    [ProducesResponseType(typeof(ScanResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<ScanResponse>> GetActiveSession(
        [FromQuery] Guid venueId,
        [FromQuery] int tableId,
        CancellationToken ct)
    {
        var session = await _dineInService.GetActiveSessionAsync(venueId, tableId, ct);

        if (session is null)
            return Ok(new ScanResponse(Guid.Empty, tableId, Guid.Empty, null, false, 0m));

        return Ok(new ScanResponse(
            session.Id,
            session.TableId,
            session.VendorId,
            session.RootOrderId,
            session.RootOrderId.HasValue,
            session.TotalSettled));
    }
}

public sealed record ScanTableRequest(Guid VenueId, Guid VendorId, int TableId);

public sealed record ScanResponse(
    Guid SessionId,
    int TableId,
    Guid VendorId,
    Guid? RootOrderId,
    bool IsAddToOrder,
    decimal TotalSettled);

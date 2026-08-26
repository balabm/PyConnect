namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

/// <summary>
/// Pub/Club guestlist management endpoints. Vendors can add, list,
/// check in, and remove guests from their venue's guestlist.
/// </summary>
[ApiController]
[Route("api/vendor/guestlist")]
[Authorize(Roles = "Vendor")]
public sealed class GuestlistController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GuestlistController(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    /// <summary>
    /// Get the current vendor's guestlist, optionally filtered by date.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<GuestlistDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<GuestlistDto>>> GetGuestlist(
        [FromQuery] DateOnly? date, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null)
            return NotFound(new { Message = "Vendor profile not found." });

        var query = _context.GuestlistEntries.AsNoTracking()
            .Where(g => g.VendorId == vendorId);

        if (date is not null)
            query = query.Where(g => g.EventDate == date);

        var entries = await query
            .OrderByDescending(g => g.CreatedAt)
            .Select(g => new GuestlistDto(
                g.Id, g.GuestName, g.PartySize, g.Phone, g.CheckedIn, g.EventDate))
            .ToListAsync(ct);

        return Ok(entries);
    }

    /// <summary>
    /// Add a guest to the guestlist.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(GuestlistDto), StatusCodes.Status201Created)]
    public async Task<ActionResult<GuestlistDto>> AddGuest(
        [FromBody] AddGuestRequest request, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null)
            return NotFound(new { Message = "Vendor profile not found." });

        var entry = GuestlistEntry.Create(
            vendorId: vendorId.Value,
            guestName: request.GuestName,
            partySize: request.PartySize ?? 1,
            phone: request.Phone,
            eventDate: request.EventDate);

        _context.GuestlistEntries.Add(entry);
        await _context.SaveChangesAsync(ct);

        return CreatedAtAction(nameof(GetGuestlist), null,
            new GuestlistDto(entry.Id, entry.GuestName, entry.PartySize, entry.Phone, entry.CheckedIn, entry.EventDate));
    }

    /// <summary>
    /// Check in a guest at the door.
    /// </summary>
    [HttpPost("{id:guid}/checkin")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> CheckIn(Guid id, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null) return NotFound();

        var entry = await _context.GuestlistEntries
            .FirstOrDefaultAsync(g => g.Id == id && g.VendorId == vendorId, ct);
        if (entry is null) return NotFound();

        entry.CheckIn();
        await _context.SaveChangesAsync(ct);
        return Ok(new { Message = "Checked in." });
    }

    /// <summary>
    /// Undo a check-in.
    /// </summary>
    [HttpPost("{id:guid}/undo-checkin")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> UndoCheckIn(Guid id, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null) return NotFound();

        var entry = await _context.GuestlistEntries
            .FirstOrDefaultAsync(g => g.Id == id && g.VendorId == vendorId, ct);
        if (entry is null) return NotFound();

        entry.UndoCheckIn();
        await _context.SaveChangesAsync(ct);
        return Ok(new { Message = "Check-in undone." });
    }

    /// <summary>
    /// Remove a guest from the guestlist.
    /// </summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> RemoveGuest(Guid id, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null) return NotFound();

        var entry = await _context.GuestlistEntries
            .FirstOrDefaultAsync(g => g.Id == id && g.VendorId == vendorId, ct);
        if (entry is null) return NotFound();

        _context.GuestlistEntries.Remove(entry);
        await _context.SaveChangesAsync(ct);
        return NoContent();
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken ct)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone)) return null;
        return await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == phone)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(ct);
    }
}

public sealed record GuestlistDto(
    Guid Id,
    string GuestName,
    int PartySize,
    string? Phone,
    bool CheckedIn,
    DateOnly EventDate);

public sealed record AddGuestRequest(
    string GuestName,
    int? PartySize = null,
    string? Phone = null,
    DateOnly? EventDate = null);

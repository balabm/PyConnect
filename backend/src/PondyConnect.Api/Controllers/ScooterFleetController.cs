namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

/// <summary>
/// Scooter fleet inventory management for ScooterRental vendors.
/// Vendors can add, update, remove, and toggle availability of
/// scooters in their rental fleet.
/// </summary>
[ApiController]
[Route("api/vendor/fleet")]
[Authorize(Roles = "Vendor")]
public sealed class ScooterFleetController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ScooterFleetController(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    /// <summary>
    /// List the current vendor's scooter fleet.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<ScooterFleetDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ScooterFleetDto>>> GetFleet(CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null)
            return NotFound(new { Message = "Vendor profile not found." });

        var fleet = await _context.ScooterFleetItems.AsNoTracking()
            .Where(s => s.VendorId == vendorId)
            .OrderByDescending(s => s.CreatedAt)
            .Select(s => new ScooterFleetDto(
                s.Id, s.Model, s.PlateNumber, s.RatePerHour, s.RatePerDay,
                s.IsAvailable, s.IsRented, s.IsElectric, s.BatteryPercent,
                s.OdometerKm, s.ImageUrl, s.Notes))
            .ToListAsync(ct);

        return Ok(fleet);
    }

    /// <summary>
    /// Add a scooter to the fleet.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(ScooterFleetDto), StatusCodes.Status201Created)]
    public async Task<ActionResult<ScooterFleetDto>> AddScooter(
        [FromBody] CreateScooterRequest request, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null)
            return NotFound(new { Message = "Vendor profile not found." });

        var scooter = ScooterFleetItem.Create(
            vendorId: vendorId.Value,
            model: request.Model,
            ratePerHour: request.RatePerHour,
            plateNumber: request.PlateNumber,
            ratePerDay: request.RatePerDay,
            isElectric: request.IsElectric ?? false,
            imageUrl: request.ImageUrl,
            batteryPercent: request.BatteryPercent,
            odometerKm: request.OdometerKm,
            notes: request.Notes);

        _context.ScooterFleetItems.Add(scooter);
        await _context.SaveChangesAsync(ct);

        return CreatedAtAction(nameof(GetFleet), null,
            new ScooterFleetDto(
                scooter.Id, scooter.Model, scooter.PlateNumber, scooter.RatePerHour,
                scooter.RatePerDay, scooter.IsAvailable, scooter.IsRented,
                scooter.IsElectric, scooter.BatteryPercent, scooter.OdometerKm,
                scooter.ImageUrl, scooter.Notes));
    }

    /// <summary>
    /// Update a scooter's details.
    /// </summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateScooter(
        Guid id, [FromBody] UpdateScooterRequest request, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null) return NotFound();

        var scooter = await _context.ScooterFleetItems
            .FirstOrDefaultAsync(s => s.Id == id && s.VendorId == vendorId, ct);
        if (scooter is null) return NotFound();

        scooter.Update(
            model: request.Model,
            ratePerHour: request.RatePerHour,
            ratePerDay: request.RatePerDay,
            plateNumber: request.PlateNumber,
            imageUrl: request.ImageUrl,
            batteryPercent: request.BatteryPercent,
            odometerKm: request.OdometerKm,
            notes: request.Notes,
            isAvailable: request.IsAvailable);

        await _context.SaveChangesAsync(ct);
        return NoContent();
    }

    /// <summary>
    /// Toggle scooter availability.
    /// </summary>
    [HttpPost("{id:guid}/toggle-availability")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> ToggleAvailability(Guid id, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null) return NotFound();

        var scooter = await _context.ScooterFleetItems
            .FirstOrDefaultAsync(s => s.Id == id && s.VendorId == vendorId, ct);
        if (scooter is null) return NotFound();

        if (scooter.IsAvailable) scooter.SetUnavailable();
        else scooter.SetAvailable();

        await _context.SaveChangesAsync(ct);
        return Ok(new { Message = "Availability toggled.", IsAvailable = scooter.IsAvailable });
    }

    /// <summary>
    /// Remove a scooter from the fleet.
    /// </summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> RemoveScooter(Guid id, CancellationToken ct)
    {
        var vendorId = await ResolveVendorIdAsync(ct);
        if (vendorId is null) return NotFound();

        var scooter = await _context.ScooterFleetItems
            .FirstOrDefaultAsync(s => s.Id == id && s.VendorId == vendorId, ct);
        if (scooter is null) return NotFound();

        _context.ScooterFleetItems.Remove(scooter);
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

public sealed record ScooterFleetDto(
    Guid Id,
    string Model,
    string? PlateNumber,
    decimal RatePerHour,
    decimal? RatePerDay,
    bool IsAvailable,
    bool IsRented,
    bool IsElectric,
    int? BatteryPercent,
    int? OdometerKm,
    string? ImageUrl,
    string? Notes);

public sealed record CreateScooterRequest(
    string Model,
    decimal RatePerHour,
    string? PlateNumber = null,
    decimal? RatePerDay = null,
    bool? IsElectric = null,
    string? ImageUrl = null,
    int? BatteryPercent = null,
    int? OdometerKm = null,
    string? Notes = null);

public sealed record UpdateScooterRequest(
    string? Model,
    decimal? RatePerHour,
    decimal? RatePerDay,
    string? PlateNumber,
    string? ImageUrl,
    int? BatteryPercent,
    int? OdometerKm,
    string? Notes,
    bool? IsAvailable);

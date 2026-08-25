namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Equipment;
using PondyConnect.Domain.Entities;

[ApiController]
[Route("api/equipment")]
[Authorize]
public sealed class EquipmentController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public EquipmentController(IMediator mediator, IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _mediator = mediator;
        _context = context;
        _currentUser = currentUser;
    }

    // ── Vendor: Inventory Management ──

    [HttpGet("items")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(IReadOnlyList<EquipmentItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<EquipmentItemDto>>> GetMyItems(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListEquipmentItemsQuery(), ct);
        return Ok(result);
    }

    [HttpPost("items")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(EquipmentItemDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<EquipmentItemDto>> CreateItem(
        [FromBody] CreateEquipmentItemRequest request, CancellationToken ct)
    {
        var command = new CreateEquipmentItemCommand(
            request.Name,
            request.DailyRentalPrice,
            request.SecurityDepositAmount,
            request.TotalUnits,
            request.Category,
            request.Description,
            request.ImageUrl);

        var result = await _mediator.Send(command, ct);
        return CreatedAtAction(nameof(GetMyItems), new { id = result.Id }, result);
    }

    [HttpPut("items/{id:guid}")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(EquipmentItemDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<EquipmentItemDto>> UpdateItem(
        Guid id, [FromBody] UpdateEquipmentItemRequest request, CancellationToken ct)
    {
        var command = new UpdateEquipmentItemCommand(
            id,
            request.DailyRentalPrice,
            request.SecurityDepositAmount,
            request.StockAdjustment);

        var result = await _mediator.Send(command, ct);
        return Ok(result);
    }

    // ── Consumer: Browse Equipment ──

    [HttpGet("browse")]
    [ProducesResponseType(typeof(IReadOnlyList<EquipmentItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<EquipmentItemDto>>> Browse(
        [FromQuery] string? category, CancellationToken ct)
    {
        var result = await _mediator.Send(new BrowseEquipmentQuery(category), ct);
        return Ok(result);
    }

    // ── Consumer: Rental Lifecycle ──

    [HttpPost("rentals")]
    [ProducesResponseType(typeof(CreateEquipmentRentalResult), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<CreateEquipmentRentalResult>> CreateRental(
        [FromBody] CreateEquipmentRentalRequest request, CancellationToken ct)
    {
        var command = new CreateEquipmentRentalCommand(
            request.EquipmentItemId,
            request.UnitsBooked,
            request.RentalStart,
            request.RentalEnd,
            request.DeliveryAddress,
            request.Notes);

        var result = await _mediator.Send(command, ct);
        return CreatedAtAction(nameof(GetMyRentals), new { id = result.RentalId }, result);
    }

    [HttpPost("rentals/{id:guid}/confirm")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> ConfirmRental(
        Guid id, [FromBody] ConfirmEquipmentRentalRequest request, CancellationToken ct)
    {
        var command = new ConfirmEquipmentRentalCommand(
            id, request.RazorpayOrderId, request.RazorpayPaymentId, request.Signature);

        await _mediator.Send(command, ct);
        return Ok(new { Message = "Rental confirmed." });
    }

    // ── Vendor: Rental Management (Kanban) ──

    [HttpGet("rentals")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(IReadOnlyList<EquipmentRentalDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<EquipmentRentalDto>>> GetMyRentals(
        [FromQuery] string? status, CancellationToken ct)
    {
        var result = await _mediator.Send(new ListEquipmentRentalsQuery(status), ct);
        return Ok(result);
    }

    [HttpPut("rentals/{id:guid}/status")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> UpdateRentalStatus(
        Guid id, [FromBody] UpdateRentalStatusRequest request, CancellationToken ct)
    {
        var command = new UpdateEquipmentRentalStatusCommand(id, request.NewStatus);
        await _mediator.Send(command, ct);
        return Ok(new { Message = "Status updated." });
    }

    [HttpPost("rentals/{id:guid}/return")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(CompleteEquipmentReturnResult), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<CompleteEquipmentReturnResult>> CompleteReturn(
        Guid id, [FromBody] CompleteReturnRequest request, CancellationToken ct)
    {
        var command = new CompleteEquipmentReturnCommand(
            id, request.LateMinutes, request.DamageAmount, request.ReturnConditionPhotosJson);

        var result = await _mediator.Send(command, ct);
        return Ok(result);
    }

    // ── Vendor: Maintenance Blocks ──

    /// <summary>
    /// Blocks a date range for an equipment item (maintenance, repair, or hold).
    /// The item will not be available for rental during the blocked period.
    /// </summary>
    [HttpPost("items/{id:guid}/block-dates")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(MaintenanceBlockResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<MaintenanceBlockResponse>> BlockDates(
        Guid id, [FromBody] BlockDatesRequest request, CancellationToken ct)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Vendor not authenticated." });

        var vendorId = await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == phone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(ct);
        if (vendorId == Guid.Empty)
            return NotFound(new { Message = "Vendor profile not found." });

        var item = await _context.EquipmentItems.AsNoTracking()
            .FirstOrDefaultAsync(e => e.Id == id && e.VendorId == vendorId, ct);
        if (item is null)
            return NotFound(new { Message = "Equipment item not found." });

        // Check for overlapping blocks
        var hasOverlap = await _context.EquipmentMaintenanceBlocks.AsNoTracking()
            .AnyAsync(b => b.EquipmentItemId == id && b.StartDate < request.EndDate && request.StartDate < b.EndDate, ct);
        if (hasOverlap)
            return BadRequest(new { Message = "Date range overlaps with an existing block." });

        var block = EquipmentMaintenanceBlock.Create(
            equipmentItemId: id,
            vendorId: vendorId,
            startDate: request.StartDate,
            endDate: request.EndDate,
            reason: request.Reason,
            notes: request.Notes);

        _context.EquipmentMaintenanceBlocks.Add(block);
        await _context.SaveChangesAsync(ct);

        return Ok(new MaintenanceBlockResponse(block.Id, block.EquipmentItemId, block.StartDate, block.EndDate, block.Reason, block.Notes));
    }

    /// <summary>
    /// Lists all maintenance blocks for an equipment item.
    /// </summary>
    [HttpGet("items/{id:guid}/block-dates")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(List<MaintenanceBlockResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<MaintenanceBlockResponse>>> GetBlocks(Guid id, CancellationToken ct)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Vendor not authenticated." });

        var vendorId = await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == phone)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(ct);
        if (vendorId == Guid.Empty)
            return NotFound(new { Message = "Vendor profile not found." });

        var blocks = await _context.EquipmentMaintenanceBlocks.AsNoTracking()
            .Where(b => b.EquipmentItemId == id && b.VendorId == vendorId)
            .OrderByDescending(b => b.StartDate)
            .Select(b => new MaintenanceBlockResponse(b.Id, b.EquipmentItemId, b.StartDate, b.EndDate, b.Reason, b.Notes))
            .ToListAsync(ct);

        return Ok(blocks);
    }

    /// <summary>
    /// Removes a maintenance block, making the item available again for
    /// the previously blocked date range.
    /// </summary>
    [HttpDelete("items/{id:guid}/block-dates/{blockId:guid}")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RemoveBlock(Guid id, Guid blockId, CancellationToken ct)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return Unauthorized(new { Message = "Vendor not authenticated." });

        var vendorId = await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == phone)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(ct);
        if (vendorId == Guid.Empty)
            return NotFound(new { Message = "Vendor profile not found." });

        var block = await _context.EquipmentMaintenanceBlocks
            .FirstOrDefaultAsync(b => b.Id == blockId && b.EquipmentItemId == id && b.VendorId == vendorId, ct);
        if (block is null)
            return NotFound(new { Message = "Maintenance block not found." });

        _context.EquipmentMaintenanceBlocks.Remove(block);
        await _context.SaveChangesAsync(ct);
        return NoContent();
    }
}

// ── Request DTOs ──

public sealed record CreateEquipmentItemRequest(
    string Name,
    decimal DailyRentalPrice,
    decimal SecurityDepositAmount,
    int TotalUnits,
    string Category = "Misc",
    string? Description = null,
    string? ImageUrl = null);

public sealed record UpdateEquipmentItemRequest(
    decimal? DailyRentalPrice,
    decimal? SecurityDepositAmount,
    int? StockAdjustment);

public sealed record CreateEquipmentRentalRequest(
    Guid EquipmentItemId,
    int UnitsBooked,
    DateTimeOffset RentalStart,
    DateTimeOffset RentalEnd,
    string? DeliveryAddress = null,
    string? Notes = null);

public sealed record ConfirmEquipmentRentalRequest(
    string RazorpayOrderId,
    string RazorpayPaymentId,
    string Signature);

public sealed record UpdateRentalStatusRequest(string NewStatus);

public sealed record CompleteReturnRequest(
    int LateMinutes = 0,
    decimal DamageAmount = 0m,
    string? ReturnConditionPhotosJson = null);

// ── Maintenance block DTOs ──

public sealed record BlockDatesRequest(
    DateTimeOffset StartDate,
    DateTimeOffset EndDate,
    string Reason = "Maintenance",
    string? Notes = null);

public sealed record MaintenanceBlockResponse(
    Guid Id,
    Guid EquipmentItemId,
    DateTimeOffset StartDate,
    DateTimeOffset EndDate,
    string Reason,
    string? Notes);

namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Features.Equipment;

[ApiController]
[Route("api/equipment")]
[Authorize]
public sealed class EquipmentController : ControllerBase
{
    private readonly IMediator _mediator;

    public EquipmentController(IMediator mediator)
    {
        _mediator = mediator;
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

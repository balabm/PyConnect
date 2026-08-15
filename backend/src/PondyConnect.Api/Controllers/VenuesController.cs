namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Features.Bookings;
using PondyConnect.Application.Features.Venues;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/venues")]
public sealed class VenuesController : ControllerBase
{
    private readonly IMediator _mediator;

    public VenuesController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<VenueFilterResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VenueFilterResponse>>> List(
        [FromQuery] string? category,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        int? categoryId = null;
        if (!string.IsNullOrWhiteSpace(category))
        {
            if (int.TryParse(category, out var catInt))
                categoryId = catInt;
            else if (Enum.TryParse<VenueCategory>(category, ignoreCase: true, out var catEnum))
                categoryId = (int)catEnum;
        }

        var venues = await _mediator.Send(new VenueFilterQuery(categoryId, OnlyActive: true, page, pageSize), cancellationToken);
        return Ok(venues);
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(VenueDetailResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VenueDetailResponse>> GetById(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var venue = await _mediator.Send(new GetVenueByIdQuery(id), cancellationToken);
            return Ok(venue);
        }
        catch (InvalidOperationException)
        {
            return NotFound(new { Message = "Venue not found or is not active." });
        }
    }

    [HttpPost("{id:guid}/book")]
    [Authorize]
    [ProducesResponseType(typeof(CreateBookingResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<CreateBookingResponse>> Book(
        Guid id,
        [FromBody] CreateBookingCommand command,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return CreatedAtAction(nameof(GetById), new { id = result.BookingId }, result);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { Message = ex.Message });
        }
    }
}
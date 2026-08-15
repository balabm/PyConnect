namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Features.Homestays;

[ApiController]
[Route("api/homestays")]
[Authorize]
public sealed class HomestaysController : ControllerBase
{
    private readonly IMediator _mediator;

    public HomestaysController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet("search")]
    [ProducesResponseType(typeof(IReadOnlyList<HomestaySearchResult>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<HomestaySearchResult>>> Search(
        [FromQuery] string checkIn,
        [FromQuery] string checkOut,
        [FromQuery] int guests = 1,
        CancellationToken cancellationToken = default)
    {
        if (!DateOnly.TryParse(checkIn, out var checkInDate))
            return BadRequest(new { Message = "Invalid checkIn date format. Use YYYY-MM-DD." });

        if (!DateOnly.TryParse(checkOut, out var checkOutDate))
            return BadRequest(new { Message = "Invalid checkOut date format. Use YYYY-MM-DD." });

        if (checkOutDate <= checkInDate)
            return BadRequest(new { Message = "Check-out date must be after check-in date." });

        var result = await _mediator.Send(new SearchHomestaysQuery(checkInDate, checkOutDate, guests), cancellationToken);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(HomestaySearchResult), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<HomestaySearchResult>> GetById(Guid id, CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new GetHomestayByIdQuery(id), cancellationToken);
        if (result is null)
            return NotFound(new { Message = "Homestay not found." });

        return Ok(result);
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<HomestaySearchResult>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<HomestaySearchResult>>> List(CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new ListVerifiedHomestaysQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpPost("book")]
    [Authorize]
    [ProducesResponseType(typeof(BookHomestayResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<BookHomestayResponse>> Book(
        [FromBody] BookHomestayCommand command,
        CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return CreatedAtAction(nameof(GetById), new { id = result.BookingId }, result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Authentication required." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }
}

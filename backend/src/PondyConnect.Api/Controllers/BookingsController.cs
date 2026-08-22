namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Features.Bookings;

[ApiController]
[Route("api/bookings")]
[Authorize]
public sealed class BookingsController : ControllerBase
{
    private readonly IMediator _mediator;

    public BookingsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpPost]
    [ProducesResponseType(typeof(CreateBookingResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<CreateBookingResponse>> Create([FromBody] CreateBookingCommand command, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return CreatedAtAction(nameof(Create), new { id = result.BookingId }, result);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { Message = ex.Message });
        }
    }

    [HttpPost("long-weekend-pass")]
    [ProducesResponseType(typeof(LongWeekendPassResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<LongWeekendPassResponse>> CreateLongWeekendPass(
        [FromBody] CreateLongWeekendPassCommand command, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Not authenticated." });
        }
    }

    [HttpPost("{id:guid}/cancel")]
    [ProducesResponseType(typeof(CancelBookingResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<CancelBookingResponse>> Cancel(Guid id, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(new CancelBookingCommand(id), cancellationToken);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    [HttpPost("{id:guid}/complete")]
    [ProducesResponseType(typeof(CompleteBookingResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<CompleteBookingResponse>> Complete(Guid id, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(new CompleteBookingCommand(id), cancellationToken);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    /// <summary>
    /// Returns the signed QR pass token and booking details for the
    /// consumer's ticket screen. The QR payload is cryptographically
    /// signed and displayed with a live clock overlay to prevent
    /// screenshot fraud.
    /// </summary>
    [HttpGet("{id:guid}/ticket")]
    [ProducesResponseType(typeof(TicketResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<TicketResponse>> GetTicket(Guid id, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(new GetTicketQuery(id), cancellationToken);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Authentication required." });
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }
}
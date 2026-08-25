namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Features.Events;

[ApiController]
[Route("api/p2p-events")]
[Authorize]
public sealed class P2pEventsController : ControllerBase
{
    private readonly IMediator _mediator;

    public P2pEventsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    // ── Event CRUD ──

    [HttpPost]
    [ProducesResponseType(typeof(P2pEventDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<P2pEventDto>> CreateEvent(
        [FromBody] CreateP2pEventRequest request, CancellationToken ct)
    {
        var command = new CreateP2pEventCommand(
            request.Title,
            request.StartsAt,
            request.EndsAt,
            request.Latitude,
            request.Longitude,
            request.EntryPrice,
            request.CapacityLimit,
            request.Description,
            request.WhatsOffered,
            request.Address,
            request.ImageUrl);

        var result = await _mediator.Send(command, ct);
        return CreatedAtAction(nameof(GetBySlug), new { slug = result.Slug }, result);
    }

    [HttpPost("{id:guid}/publish")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> PublishEvent(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new PublishP2pEventCommand(id), ct);
        return Ok(new { Message = "Event published." });
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<P2pEventDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<P2pEventDto>>> BrowseEvents(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListP2pEventsQuery(), ct);
        return Ok(result);
    }

    [HttpGet("{slug}")]
    [ProducesResponseType(typeof(P2pEventDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<P2pEventDto>> GetBySlug(string slug, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetP2pEventBySlugQuery(slug), ct);
        return Ok(result);
    }

    [HttpGet("my-events")]
    [ProducesResponseType(typeof(IReadOnlyList<P2pEventDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<P2pEventDto>>> MyEvents(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListMyHostedEventsQuery(), ct);
        return Ok(result);
    }

    [HttpPost("{id:guid}/cancel")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CancelEvent(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new CancelP2pEventCommand(id), ct);
        return Ok(new { Message = "Event cancelled. All ticket holders will be refunded." });
    }

    // ── Ticketing ──

    [HttpPost("{id:guid}/tickets")]
    [ProducesResponseType(typeof(BuyTicketResult), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<BuyTicketResult>> BuyTicket(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new BuyP2pEventTicketCommand(id), ct);
        return CreatedAtAction(nameof(MyEvents), new { id = result.TicketId }, result);
    }

    [HttpPost("tickets/{ticketId:guid}/confirm")]
    [ProducesResponseType(typeof(ConfirmTicketResult), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<ConfirmTicketResult>> ConfirmTicket(
        Guid ticketId, [FromBody] ConfirmTicketRequest request, CancellationToken ct)
    {
        var command = new ConfirmP2pTicketPaymentCommand(
            ticketId, request.RazorpayOrderId, request.RazorpayPaymentId, request.Signature);
        var result = await _mediator.Send(command, ct);
        return Ok(result);
    }

    // ── Host Scanner ──

    [HttpPost("{id:guid}/validate-ticket")]
    [ProducesResponseType(typeof(P2pTicketValidationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<P2pTicketValidationResponse>> ValidateTicket(
        Guid id, [FromBody] ValidateP2pTicketRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new ValidateP2pTicketCommand(id, request.QrPayload), ct);
        return Ok(result);
    }

    // ── Attendees ──

    [HttpGet("{id:guid}/attendees")]
    [ProducesResponseType(typeof(IReadOnlyList<AttendeeDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<AttendeeDto>>> GetAttendees(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetP2pEventAttendeesQuery(id), ct);
        return Ok(result);
    }
}

// ── Request DTOs ──

public sealed record CreateP2pEventRequest(
    string Title,
    DateTimeOffset StartsAt,
    DateTimeOffset EndsAt,
    double Latitude,
    double Longitude,
    decimal EntryPrice = 0m,
    int CapacityLimit = 50,
    string? Description = null,
    string? WhatsOffered = null,
    string? Address = null,
    string? ImageUrl = null);

public sealed record ConfirmTicketRequest(
    string RazorpayOrderId,
    string RazorpayPaymentId,
    string Signature);

public sealed record ValidateP2pTicketRequest(string QrPayload);

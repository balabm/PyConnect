namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Transit;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/transit")]
[Authorize]
public sealed class TransitController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ICurrentUserService _currentUser;

    public TransitController(IMediator mediator, ICurrentUserService currentUser)
    {
        _mediator = mediator;
        _currentUser = currentUser;
    }

    [HttpGet("hubs")]
    [ProducesResponseType(typeof(IReadOnlyList<TransitHubResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<TransitHubResponse>>> ListHubs(
        [FromQuery] TransitHubKind? kind = null,
        [FromQuery] bool onlyActive = true,
        CancellationToken cancellationToken = default)
    {
        var hubs = await _mediator.Send(new ListTransitHubsQuery(kind, onlyActive), cancellationToken);
        return Ok(hubs);
    }

    [HttpGet("hubs/{id:guid}")]
    [ProducesResponseType(typeof(TransitHubDetailResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<TransitHubDetailResponse>> GetHub(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var hub = await _mediator.Send(new GetTransitHubQuery(id), cancellationToken);
            return Ok(hub);
        }
        catch (InvalidOperationException)
        {
            return NotFound(new { Message = "Transit hub not found." });
        }
    }

    [HttpPost("trips")]
    [ProducesResponseType(typeof(CreateTransitTripResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<CreateTransitTripResponse>> CreateTrip(
        [FromBody] CreateTransitTripCommand command,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return CreatedAtAction(nameof(GetTrips), new { id = result.TripId }, result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    [HttpGet("trips")]
    [ProducesResponseType(typeof(IReadOnlyList<TransitTripResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<TransitTripResponse>>> GetTrips(
        [FromQuery] TransitStatus? status = null,
        CancellationToken cancellationToken = default)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var trips = await _mediator.Send(new ListUserTripsQuery(userId, status), cancellationToken);
        return Ok(trips);
    }
}
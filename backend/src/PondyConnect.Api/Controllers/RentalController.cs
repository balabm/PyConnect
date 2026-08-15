namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Api.Filters;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Rental;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/rental")]
[Authorize]
public sealed class RentalController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ICurrentUserService _currentUser;

    public RentalController(IMediator mediator, ICurrentUserService currentUser)
    {
        _mediator = mediator;
        _currentUser = currentUser;
    }

    [HttpPost("scooters")]
    [RequireWaiver]
    [ProducesResponseType(typeof(CreateScooterRentalResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<CreateScooterRentalResponse>> CreateRental(
        [FromBody] CreateScooterRentalCommand command,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return CreatedAtAction(nameof(GetRentals), new { id = result.RentalId }, result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    [HttpGet("scooters")]
    [ProducesResponseType(typeof(IReadOnlyList<ScooterRentalResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ScooterRentalResponse>>> GetRentals(
        [FromQuery] RentalStatus? status = null,
        CancellationToken cancellationToken = default)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var rentals = await _mediator.Send(new ListUserRentalsQuery(userId, status), cancellationToken);
        return Ok(rentals);
    }
}
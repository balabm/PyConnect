namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Luggage;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/luggage")]
[Authorize]
public sealed class LuggageController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ICurrentUserService _currentUser;

    public LuggageController(IMediator mediator, ICurrentUserService currentUser)
    {
        _mediator = mediator;
        _currentUser = currentUser;
    }

    [HttpPost("drop-offs")]
    [ProducesResponseType(typeof(CreateLuggageDropOffResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<CreateLuggageDropOffResponse>> CreateDropOff(
        [FromBody] CreateLuggageDropOffCommand command,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return CreatedAtAction(nameof(GetDropOffs), new { id = result.DropOffId }, result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    [HttpGet("drop-offs")]
    [ProducesResponseType(typeof(IReadOnlyList<LuggageDropOffResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<LuggageDropOffResponse>>> GetDropOffs(
        [FromQuery] LuggageStatus? status = null,
        CancellationToken cancellationToken = default)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var dropOffs = await _mediator.Send(new ListUserLuggageQuery(userId, status), cancellationToken);
        return Ok(dropOffs);
    }

    [HttpGet("drop-offs/{id:guid}")]
    [ProducesResponseType(typeof(LuggageDropOffResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LuggageDropOffResponse>> GetDropOff(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _mediator.Send(new GetLuggageDropOffQuery(id), cancellationToken);
            return Ok(result);
        }
        catch (InvalidOperationException)
        {
            return NotFound(new { Message = "Luggage drop-off not found." });
        }
    }

    [HttpPost("drop-offs/{id:guid}/cancel")]
    [ProducesResponseType(typeof(CancelLuggageDropOffResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<CancelLuggageDropOffResponse>> CancelDropOff(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _mediator.Send(new CancelLuggageDropOffCommand(id), cancellationToken);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }
}
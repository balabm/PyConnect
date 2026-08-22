namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
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
    private readonly IApplicationDbContext _context;

    public LuggageController(IMediator mediator, ICurrentUserService currentUser, IApplicationDbContext context)
    {
        _mediator = mediator;
        _currentUser = currentUser;
        _context = context;
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

    /// <summary>
    /// Generates a time-sensitive 6-digit retrieval PIN for secure bag
    /// pickup. The Consumer shows this PIN (or a QR code containing it)
    /// to the Partner, who scans or manually enters it to collect the
    /// bags. The PIN expires after 10 minutes.
    /// </summary>
    [HttpPost("drop-offs/{id:guid}/generate-pin")]
    [ProducesResponseType(typeof(RetrievalPinResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<RetrievalPinResponse>> GenerateRetrievalPin(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "Authentication required." });

        var dropOff = await _context.LuggageDropOffs
            .FirstOrDefaultAsync(d => d.Id == id && d.UserId == userId, cancellationToken);
        if (dropOff is null)
            return NotFound(new { Message = "Drop-off not found or does not belong to you." });

        try
        {
            dropOff.GenerateRetrievalPin();
            await _context.SaveChangesAsync(cancellationToken);

            // The QR payload encodes the drop-off ID and PIN so the
            // Partner's scanner can validate it in one scan.
            var qrPayload = $"pyconnect:retrieval:{dropOff.Id}:{dropOff.RetrievalPin}";

            return Ok(new RetrievalPinResponse(dropOff.Id, dropOff.RetrievalPin!, qrPayload, 10));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }
}

public sealed record RetrievalPinResponse(Guid DropOffId, string Pin, string QrPayload, int ExpiresInMinutes);
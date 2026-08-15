namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

[ApiController]
[Route("api/waitlist")]
public sealed class WaitlistController : ControllerBase
{
    private readonly IApplicationDbContext _dbContext;

    public WaitlistController(IApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    [HttpPost("join")]
    [ProducesResponseType(typeof(WaitlistJoinResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(WaitlistJoinResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<WaitlistJoinResponse>> Join([FromBody] JoinWaitlistRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.PhoneNumber) || request.PhoneNumber.Length < 10)
            return BadRequest(new { Message = "A valid phone number is required." });

        var existing = await _dbContext.WaitlistEntries
            .FirstOrDefaultAsync(w => w.PhoneNumber == request.PhoneNumber, cancellationToken);

        if (existing is not null)
        {
            var position = await GetPositionAsync(existing.CreatedAt, cancellationToken);
            return Ok(new WaitlistJoinResponse(existing.Id, position, true));
        }

        var entry = WaitlistEntry.Create(request.PhoneNumber, request.SourceQrCodeLocation);
        _dbContext.WaitlistEntries.Add(entry);
        await _dbContext.SaveChangesAsync(cancellationToken);

        var pos = await GetPositionAsync(entry.CreatedAt, cancellationToken);
        return CreatedAtAction(nameof(Join), new { }, new WaitlistJoinResponse(entry.Id, pos, false));
    }

    private async Task<int> GetPositionAsync(DateTimeOffset createdAt, CancellationToken cancellationToken)
    {
        var entries = await _dbContext.WaitlistEntries
            .AsNoTracking()
            .ToListAsync(cancellationToken);
        return entries.Count(w => w.CreatedAt <= createdAt);
    }
}

public sealed record JoinWaitlistRequest(string PhoneNumber, string? SourceQrCodeLocation = null);

public sealed record WaitlistJoinResponse(Guid Id, int Position, bool AlreadyOnWaitlist);

namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Tickets;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/tickets")]
[Authorize]
public sealed class TicketingController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public TicketingController(
        IMediator mediator,
        IApplicationDbContext context,
        ICurrentUserService currentUser)
    {
        _mediator = mediator;
        _context = context;
        _currentUser = currentUser;
    }

    [HttpPost]
    [ProducesResponseType(typeof(CreateTicketResult), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<CreateTicketResult>> CreateTicket(
        [FromBody] CreateTicketRequest request,
        CancellationToken ct)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var command = new CreateTicketCommand(
            userId.ToString(),
            request.Category,
            request.Subject,
            request.Description,
            request.OrderId,
            request.OrderType,
            request.PhotoUrl);

        var result = await _mediator.Send(command, ct);

        return CreatedAtAction(
            nameof(GetTicket),
            new { id = result.TicketId },
            result);
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<DisputeTicketSummary>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<DisputeTicketSummary>>> GetMyTickets(CancellationToken ct)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var userIdString = userId.ToString();

        var tickets = await _context.DisputeTickets
            .AsNoTracking()
            .Where(t => t.UserId == userIdString)
            .OrderByDescending(t => t.CreatedAt)
            .Select(t => new DisputeTicketSummary(
                t.Id,
                t.Category.ToString(),
                t.Subject,
                t.Status.ToString(),
                t.ResolutionAmount,
                t.CreatedAt))
            .ToListAsync(ct);

        return Ok(tickets);
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(DisputeTicketDetail), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<DisputeTicketDetail>> GetTicket(Guid id, CancellationToken ct)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var userIdString = userId.ToString();

        var ticket = await _context.DisputeTickets
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.Id == id && t.UserId == userIdString, ct);

        if (ticket is null)
            return NotFound(new { Message = "Ticket not found." });

        return Ok(new DisputeTicketDetail(
            ticket.Id,
            ticket.Category.ToString(),
            ticket.Subject,
            ticket.Description,
            ticket.PhotoUrl,
            ticket.Status.ToString(),
            ticket.ResolutionAmount,
            ticket.ResolutionNote,
            ticket.OrderId,
            ticket.OrderType,
            ticket.CreatedAt,
            ticket.ResolvedAt));
    }

    [HttpGet("~/api/admin/tickets")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(typeof(IReadOnlyList<AdminDisputeTicketSummary>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<AdminDisputeTicketSummary>>> GetAllTickets(
        [FromQuery] SupportTicketStatus? status = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken ct = default)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 200);

        var query = _context.DisputeTickets.AsNoTracking();

        if (status.HasValue)
            query = query.Where(t => t.Status == status.Value);

        var tickets = await query
            .OrderByDescending(t => t.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        var userGuids = tickets
            .Select(t => t.UserId)
            .Where(s => Guid.TryParse(s, out _))
            .Select(Guid.Parse)
            .ToList();

        var users = await _context.Users
            .AsNoTracking()
            .Where(u => userGuids.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id.ToString(), u => new { u.Name, u.Phone }, ct);

        var result = tickets
            .Select(t =>
            {
                users.TryGetValue(t.UserId, out var user);
                return new AdminDisputeTicketSummary(
                    t.Id,
                    t.UserId,
                    user?.Name ?? "Unknown",
                    user?.Phone ?? string.Empty,
                    t.Category.ToString(),
                    t.Subject,
                    t.Status.ToString(),
                    t.ResolutionAmount,
                    t.CreatedAt);
            })
            .ToList();

        return Ok(result);
    }
}

public sealed record CreateTicketRequest(
    SupportTicketCategory Category,
    string Subject,
    string Description,
    Guid? OrderId = null,
    string? OrderType = null,
    string? PhotoUrl = null);

public sealed record DisputeTicketSummary(
    Guid Id,
    string Category,
    string Subject,
    string Status,
    decimal? ResolutionAmount,
    DateTimeOffset CreatedAt);

public sealed record DisputeTicketDetail(
    Guid Id,
    string Category,
    string Subject,
    string Description,
    string? PhotoUrl,
    string Status,
    decimal? ResolutionAmount,
    string? ResolutionNote,
    Guid? OrderId,
    string? OrderType,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt);

public sealed record AdminDisputeTicketSummary(
    Guid Id,
    string UserId,
    string UserName,
    string UserPhone,
    string Category,
    string Subject,
    string Status,
    decimal? ResolutionAmount,
    DateTimeOffset CreatedAt);

namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Support;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/support")]
public sealed class SupportController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly MessageReceiverService _messageReceiver;

    public SupportController(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        MessageReceiverService messageReceiver)
    {
        _context = context;
        _currentUser = currentUser;
        _messageReceiver = messageReceiver;
    }

    [HttpPost("message")]
    [Authorize]
    [ProducesResponseType(typeof(MessageResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<MessageResponse>> SendMessage(
        [FromBody] SendMessageRequest request,
        CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var result = await _messageReceiver.ReceiveMessageAsync(
            userId,
            request.MessageText,
            TicketSource.InApp,
            cancellationToken);

        return Ok(result);
    }

    [HttpPost("sos")]
    [Authorize]
    [ProducesResponseType(typeof(CriticalTicketNotification), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<CriticalTicketNotification>> CreateSos(
        [FromBody] CreateSosRequest request,
        CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var result = await _messageReceiver.CreateSosTicketAsync(
            userId,
            request.Issue,
            request.Latitude,
            request.Longitude,
            cancellationToken);

        return CreatedAtAction(nameof(GetTicket), new { id = result.TicketId }, result);
    }

    [HttpGet("tickets")]
    [Authorize]
    [ProducesResponseType(typeof(IReadOnlyList<TicketSummary>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<TicketSummary>>> GetMyTickets(
        CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var tickets = (await _context.SupportTickets
            .Where(t => t.UserId == userId)
            .ToListAsync(cancellationToken))
            .OrderByDescending(t => t.CreatedAt)
            .Select(t => new TicketSummary(
                t.Id,
                t.Status.ToString(),
                t.Priority.ToString(),
                t.Source.ToString(),
                t.IssueCategory,
                t.CreatedAt))
            .ToList();

        return Ok(tickets);
    }

    [HttpGet("tickets/{id:guid}/messages")]
    [Authorize]
    [ProducesResponseType(typeof(IReadOnlyList<TicketMessageDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IReadOnlyList<TicketMessageDto>>> GetTicketMessages(
        Guid id,
        CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId;
        var isAdmin = User.IsInRole("Admin");

        // Validate ownership: only the ticket owner or an admin can view messages.
        if (!isAdmin && userId.HasValue)
        {
            var ownsTicket = await _context.SupportTickets
                .AnyAsync(t => t.Id == id && t.UserId == userId.Value, cancellationToken);
            if (!ownsTicket)
                return NotFound(new { Message = "Ticket not found." });
        }

        var messages = (await _context.TicketMessages
            .Where(m => m.TicketId == id)
            .ToListAsync(cancellationToken))
            .OrderBy(m => m.CreatedAt)
            .Select(m => new TicketMessageDto(
                m.Id,
                m.SenderRole.ToString(),
                m.MessageText,
                m.CreatedAt))
            .ToList();

        return Ok(messages);
    }

    [HttpGet("tickets/{id:guid}")]
    [Authorize]
    [ProducesResponseType(typeof(TicketSummary), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<TicketSummary>> GetTicket(Guid id, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId;
        var isAdmin = User.IsInRole("Admin");

        var ticketQuery = _context.SupportTickets.Where(t => t.Id == id);

        // Non-admins can only view their own tickets.
        if (!isAdmin && userId.HasValue)
            ticketQuery = ticketQuery.Where(t => t.UserId == userId.Value);

        var ticket = await ticketQuery
            .Select(t => new TicketSummary(
                t.Id,
                t.Status.ToString(),
                t.Priority.ToString(),
                t.Source.ToString(),
                t.IssueCategory,
                t.CreatedAt))
            .FirstOrDefaultAsync(cancellationToken);

        if (ticket is null)
            return NotFound(new { Message = "Ticket not found." });

        return Ok(ticket);
    }

    [HttpGet("critical")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(typeof(IReadOnlyList<CriticalTicketDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<CriticalTicketDto>>> GetCriticalTickets(
        CancellationToken cancellationToken)
    {
        var tickets = (await _context.SupportTickets
            .Where(t => t.Priority == TicketPriority.Critical
                && (t.Status == SupportTicketStatus.Open || t.Status == SupportTicketStatus.Escalated))
            .ToListAsync(cancellationToken))
            .OrderByDescending(t => t.CreatedAt);

        var users = await _context.Users
            .ToListAsync(cancellationToken);

        var result = tickets
            .Join(users,
                t => t.UserId,
                u => u.Id,
                (t, u) => new CriticalTicketDto(
                    t.Id,
                    t.UserId,
                    u.Name,
                    u.Phone,
                    t.IssueCategory,
                    t.Latitude,
                    t.Longitude,
                    t.Priority.ToString(),
                    t.Source.ToString(),
                    t.Status.ToString(),
                    t.CreatedAt,
                    t.AcknowledgedAt))
            .ToList();

        return Ok(result);
    }

    [HttpPost("tickets/{id:guid}/acknowledge")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> AcknowledgeTicket(Guid id, CancellationToken cancellationToken)
    {
        var ticket = await _context.SupportTickets
            .FirstOrDefaultAsync(t => t.Id == id, cancellationToken);

        if (ticket is null)
            return NotFound(new { Message = "Ticket not found." });

        ticket.Acknowledge();
        await _context.SaveChangesAsync(cancellationToken);

        return Ok(new { Message = "Ticket acknowledged." });
    }
}

public sealed record SendMessageRequest(string MessageText);

public sealed record CreateSosRequest(string Issue, double? Latitude, double? Longitude);

public sealed record TicketSummary(
    Guid Id,
    string Status,
    string Priority,
    string Source,
    string? IssueCategory,
    DateTimeOffset CreatedAt);

public sealed record TicketMessageDto(
    Guid Id,
    string SenderRole,
    string MessageText,
    DateTimeOffset CreatedAt);

public sealed record CriticalTicketDto(
    Guid Id,
    Guid UserId,
    string UserName,
    string UserPhone,
    string? IssueCategory,
    double? Latitude,
    double? Longitude,
    string Priority,
    string Source,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? AcknowledgedAt);

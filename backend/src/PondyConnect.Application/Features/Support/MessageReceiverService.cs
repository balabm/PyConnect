namespace PondyConnect.Application.Features.Support;

using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed record MessageResponse(
    Guid TicketId,
    string AiReply,
    bool IsCritical,
    string Priority,
    string DetectedIntent);

public sealed record CriticalTicketNotification(
    Guid TicketId,
    Guid UserId,
    string UserName,
    string IssueCategory,
    double? Latitude,
    double? Longitude,
    string Priority,
    string Source,
    DateTimeOffset CreatedAt);

public sealed class MessageReceiverService
{
    private readonly IApplicationDbContext _context;
    private readonly UserContextService _userContextService;
    private readonly ILlmService _llmService;
    private readonly ICriticalTicketBroadcaster _broadcaster;

    public MessageReceiverService(
        IApplicationDbContext context,
        UserContextService userContextService,
        ILlmService llmService,
        ICriticalTicketBroadcaster broadcaster)
    {
        _context = context;
        _userContextService = userContextService;
        _llmService = llmService;
        _broadcaster = broadcaster;
    }

    public async Task<MessageResponse> ReceiveMessageAsync(
        Guid userId,
        string messageText,
        TicketSource source = TicketSource.InApp,
        CancellationToken cancellationToken = default)
    {
        var activeBookingsJson = await _userContextService.GetActiveBookingsJsonAsync(userId, cancellationToken);

        var systemPrompt = $"""
            You are PondyConnect's AI support assistant for Pondicherry.
            The user has the following active bookings:
            {activeBookingsJson}
            Help the user with their query. If the issue is severe (accident, breakdown, safety), flag it as critical.
            """;

        var llmResponse = await _llmService.GenerateResponseAsync(systemPrompt, messageText, cancellationToken);

        var ticket = (await _context.SupportTickets
            .Where(t => t.UserId == userId
                && (t.Status == SupportTicketStatus.Open || t.Status == SupportTicketStatus.InProgress))
            .ToListAsync(cancellationToken))
            .OrderByDescending(t => t.CreatedAt)
            .FirstOrDefault();

        if (ticket is null)
        {
            var priority = llmResponse.IsCritical ? TicketPriority.Critical : TicketPriority.Normal;
            ticket = SupportTicket.Create(userId, priority, source);
            if (llmResponse.IsCritical)
                ticket.Escalate();
            _context.SupportTickets.Add(ticket);
            await _context.SaveChangesAsync(cancellationToken);
        }
        else
        {
            if (llmResponse.IsCritical && ticket.Priority != TicketPriority.Critical)
            {
                ticket.Escalate();
            }
            else
            {
                ticket.MarkInProgress();
            }
        }

        var userMessage = TicketMessage.Create(ticket.Id, MessageSenderRole.User, messageText);
        var aiMessage = TicketMessage.Create(ticket.Id, MessageSenderRole.AI, llmResponse.Reply);

        _context.TicketMessages.Add(userMessage);
        _context.TicketMessages.Add(aiMessage);
        await _context.SaveChangesAsync(cancellationToken);

        if (llmResponse.IsCritical)
        {
            var user = await _context.Users
                .Where(u => u.Id == userId)
                .Select(u => u.Name)
                .FirstOrDefaultAsync(cancellationToken);

            var notification = new CriticalTicketNotification(
                ticket.Id,
                userId,
                user ?? "Unknown",
                ticket.IssueCategory ?? "AI Detected",
                ticket.Latitude,
                ticket.Longitude,
                ticket.Priority.ToString(),
                ticket.Source.ToString(),
                ticket.CreatedAt);

            await _broadcaster.BroadcastCriticalAsync(notification, cancellationToken);
        }

        return new MessageResponse(
            ticket.Id,
            llmResponse.Reply,
            llmResponse.IsCritical,
            ticket.Priority.ToString(),
            llmResponse.DetectedIntent);
    }

    public async Task<CriticalTicketNotification> CreateSosTicketAsync(
        Guid userId,
        string issueCategory,
        double? latitude,
        double? longitude,
        CancellationToken cancellationToken = default)
    {
        var ticket = SupportTicket.Create(
            userId,
            TicketPriority.Critical,
            TicketSource.SOS,
            latitude,
            longitude,
            issueCategory);
        ticket.Escalate();

        _context.SupportTickets.Add(ticket);

        var message = TicketMessage.Create(
            ticket.Id,
            MessageSenderRole.User,
            $"SOS: {issueCategory}");
        _context.TicketMessages.Add(message);

        await _context.SaveChangesAsync(cancellationToken);

        var user = await _context.Users
            .Where(u => u.Id == userId)
            .Select(u => u.Name)
            .FirstOrDefaultAsync(cancellationToken);

        var notification = new CriticalTicketNotification(
            ticket.Id,
            userId,
            user ?? "Unknown",
            issueCategory,
            latitude,
            longitude,
            ticket.Priority.ToString(),
            ticket.Source.ToString(),
            ticket.CreatedAt);

        await _broadcaster.BroadcastCriticalAsync(notification, cancellationToken);

        return notification;
    }
}

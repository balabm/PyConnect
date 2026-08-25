namespace PondyConnect.Application.Features.Events;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Wallet;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

// ── Create P2P Event ──

public sealed record CreateP2pEventCommand(
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
    string? ImageUrl = null) : IRequest<P2pEventDto>;

public sealed record P2pEventDto(
    Guid Id,
    string Title,
    string Slug,
    string? Description,
    string? WhatsOffered,
    DateTimeOffset StartsAt,
    DateTimeOffset EndsAt,
    double Latitude,
    double Longitude,
    string? Address,
    decimal EntryPrice,
    int CapacityLimit,
    int TicketsSold,
    string Status,
    string? ImageUrl,
    bool IsHost);

public sealed class CreateP2pEventCommandHandler : IRequestHandler<CreateP2pEventCommand, P2pEventDto>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateP2pEventCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<P2pEventDto> Handle(CreateP2pEventCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var slug = await GenerateUniqueSlugAsync(request.Title, cancellationToken);

        var location = GeoLocation.Create(request.Latitude, request.Longitude);

        var evt = P2pEvent.Create(
            userId,
            request.Title,
            slug,
            request.StartsAt,
            request.EndsAt,
            location,
            request.EntryPrice,
            request.CapacityLimit,
            request.Description,
            request.WhatsOffered,
            request.Address,
            request.ImageUrl);

        _context.P2pEvents.Add(evt);
        await _context.SaveChangesAsync(cancellationToken);

        return ToDto(evt, isHost: true);
    }

    internal static string Slugify(string title)
    {
        var slug = System.Text.RegularExpressions.Regex.Replace(title.ToLowerInvariant(), @"[^a-z0-9]+", "-");
        slug = slug.Trim('-');
        if (slug.Length > 40) slug = slug[..40];
        return string.IsNullOrWhiteSpace(slug) ? "event" : slug;
    }

    private async Task<string> GenerateUniqueSlugAsync(string title, CancellationToken cancellationToken)
    {
        var baseSlug = Slugify(title);
        for (var attempt = 0; attempt < 10; attempt++)
        {
            var suffix = Guid.NewGuid().ToString("N")[..6];
            var slug = $"{baseSlug}-{suffix}";
            var exists = await _context.P2pEvents.AnyAsync(e => e.Slug == slug, cancellationToken);
            if (!exists) return slug;
        }
        // Fallback: full GUID
        return $"{baseSlug}-{Guid.NewGuid():N}";
    }

    internal static P2pEventDto ToDto(P2pEvent e, bool isHost) => new(
        e.Id, e.Title, e.Slug, e.Description, e.WhatsOffered,
        e.StartsAt, e.EndsAt, e.Location.Latitude, e.Location.Longitude,
        e.Address, e.EntryPrice, e.CapacityLimit, e.TicketsSold,
        e.Status.ToString(), e.ImageUrl, isHost);
}

// ── Publish Event ──

public sealed record PublishP2pEventCommand(Guid EventId) : IRequest<Unit>;

public sealed class PublishP2pEventCommandHandler : IRequestHandler<PublishP2pEventCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public PublishP2pEventCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(PublishP2pEventCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var evt = await _context.P2pEvents
            .FirstOrDefaultAsync(e => e.Id == request.EventId && e.HostUserId == userId, cancellationToken)
            ?? throw new UnauthorizedAccessException("Event not found or not owned by user.");

        evt.Publish();
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

// ── Get Event By Slug (public, for deep link) ──

public sealed record GetP2pEventBySlugQuery(string Slug) : IRequest<P2pEventDto>;

public sealed class GetP2pEventBySlugHandler : IRequestHandler<GetP2pEventBySlugQuery, P2pEventDto>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetP2pEventBySlugHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<P2pEventDto> Handle(GetP2pEventBySlugQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId;

        var evt = await _context.P2pEvents
            .AsNoTracking()
            .FirstOrDefaultAsync(e => e.Slug == request.Slug, cancellationToken)
            ?? throw new InvalidOperationException("Event not found.");

        var isHost = userId.HasValue && evt.HostUserId == userId.Value;
        return CreateP2pEventCommandHandler.ToDto(evt, isHost);
    }
}

// ── Browse Published Events ──

public sealed record ListP2pEventsQuery() : IRequest<IReadOnlyList<P2pEventDto>>;

public sealed class ListP2pEventsHandler : IRequestHandler<ListP2pEventsQuery, IReadOnlyList<P2pEventDto>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListP2pEventsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<P2pEventDto>> Handle(ListP2pEventsQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId;
        var now = DateTimeOffset.UtcNow;

        var events = await _context.P2pEvents
            .AsNoTracking()
            .Where(e => e.Status == P2pEventStatus.Published || e.Status == P2pEventStatus.SoldOut)
            .Where(e => e.StartsAt > now)
            .OrderBy(e => e.StartsAt)
            .ToListAsync(cancellationToken);

        return events.Select(e => CreateP2pEventCommandHandler.ToDto(e, userId.HasValue && e.HostUserId == userId.Value)).ToList();
    }
}

// ── List My Hosted Events ──

public sealed record ListMyHostedEventsQuery() : IRequest<IReadOnlyList<P2pEventDto>>;

public sealed class ListMyHostedEventsHandler : IRequestHandler<ListMyHostedEventsQuery, IReadOnlyList<P2pEventDto>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListMyHostedEventsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<P2pEventDto>> Handle(ListMyHostedEventsQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var events = await _context.P2pEvents
            .AsNoTracking()
            .Where(e => e.HostUserId == userId)
            .OrderByDescending(e => e.CreatedAt)
            .ToListAsync(cancellationToken);

        return events.Select(e => CreateP2pEventCommandHandler.ToDto(e, isHost: true)).ToList();
    }
}

// ── Buy Ticket ──

public sealed record BuyP2pEventTicketCommand(Guid EventId) : IRequest<BuyTicketResult>;

public sealed record BuyTicketResult(
    Guid TicketId,
    decimal PricePaid,
    string? RazorpayOrderId);

public sealed class BuyP2pEventTicketHandler : IRequestHandler<BuyP2pEventTicketCommand, BuyTicketResult>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IPaymentGateway _paymentGateway;

    public BuyP2pEventTicketHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IPaymentGateway paymentGateway)
    {
        _context = context;
        _currentUser = currentUser;
        _paymentGateway = paymentGateway;
    }

    public async Task<BuyTicketResult> Handle(BuyP2pEventTicketCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var evt = await _context.P2pEvents
            .FirstOrDefaultAsync(e => e.Id == request.EventId, cancellationToken)
            ?? throw new InvalidOperationException("Event not found.");

        if (evt.Status != P2pEventStatus.Published)
            throw new InvalidOperationException("Event is not available for ticket sales.");

        if (evt.HostUserId == userId)
            throw new InvalidOperationException("Host cannot buy tickets for their own event.");

        // Check if user already has an active ticket
        var existingTicket = await _context.P2pEventTickets
            .AnyAsync(t => t.P2pEventId == request.EventId && t.BuyerUserId == userId && t.Status == "Active", cancellationToken);
        if (existingTicket)
            throw new InvalidOperationException("You already have a ticket for this event.");

        // Check capacity
        if (evt.TicketsSold >= evt.CapacityLimit)
            throw new InvalidOperationException("Event is sold out.");

        var ticket = P2pEventTicket.Create(evt.Id, userId, evt.EntryPrice, evt.PlatformFeePercent);
        _context.P2pEventTickets.Add(ticket);

        // Increment sold count
        evt.IncrementTickets();

        string? razorpayOrderId = null;
        if (evt.EntryPrice > 0)
        {
            var receipt = $"p2p-{ticket.Id.ToString().Substring(0, 8)}";
            var order = await _paymentGateway.CreateOrderAsync(
                evt.EntryPrice, "INR", receipt, capture: true, cancellationToken: cancellationToken);

            if (!order.Success || order.OrderId is null)
                throw new InvalidOperationException(order.ErrorMessage ?? "Failed to create payment order.");

            razorpayOrderId = order.OrderId;
        }
        else
        {
            // Free event — issue pass token immediately
            ticket.IssuePassToken($"p2p-{ticket.Id:N}");
            ticket.RecordPayment(PaymentStatus.Captured, "free");
        }

        await _context.SaveChangesAsync(cancellationToken);

        return new BuyTicketResult(ticket.Id, evt.EntryPrice, razorpayOrderId);
    }
}

// ── Confirm Ticket Payment ──

public sealed record ConfirmP2pTicketPaymentCommand(
    Guid TicketId,
    string RazorpayOrderId,
    string RazorpayPaymentId,
    string Signature) : IRequest<ConfirmTicketResult>;

public sealed record ConfirmTicketResult(string PassToken);

public sealed class ConfirmP2pTicketPaymentHandler : IRequestHandler<ConfirmP2pTicketPaymentCommand, ConfirmTicketResult>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IPaymentGateway _paymentGateway;
    private readonly WalletService _walletService;

    public ConfirmP2pTicketPaymentHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IPaymentGateway paymentGateway,
        WalletService walletService)
    {
        _context = context;
        _currentUser = currentUser;
        _paymentGateway = paymentGateway;
        _walletService = walletService;
    }

    public async Task<ConfirmTicketResult> Handle(ConfirmP2pTicketPaymentCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var ticket = await _context.P2pEventTickets
            .FirstOrDefaultAsync(t => t.Id == request.TicketId && t.BuyerUserId == userId, cancellationToken)
            ?? throw new UnauthorizedAccessException("Ticket not found or not owned by user.");

        if (ticket.PaymentStatus == PaymentStatus.Captured)
            throw new InvalidOperationException("Ticket is already paid.");

        var valid = await _paymentGateway.VerifyPaymentSignatureAsync(
            request.RazorpayOrderId, request.RazorpayPaymentId, request.Signature, cancellationToken);
        if (!valid)
            throw new InvalidOperationException("Invalid payment signature.");

        ticket.RecordPayment(PaymentStatus.Captured, request.RazorpayPaymentId);

        // Issue QR pass token
        var passToken = $"p2p-{ticket.Id:N}";
        ticket.IssuePassToken(passToken);

        // Credit host payout (95%) to host's wallet
        if (ticket.HostPayout > 0)
        {
            var evt = await _context.P2pEvents
                .AsNoTracking()
                .FirstOrDefaultAsync(e => e.Id == ticket.P2pEventId, cancellationToken);

            if (evt is not null)
            {
                await _walletService.CreditHostPayoutAsync(
                    evt.HostUserId,
                    ticket.HostPayout,
                    $"p2p-ticket-{ticket.Id}",
                    $"P2P event ticket: {evt.Title}",
                    cancellationToken);
            }
        }

        await _context.SaveChangesAsync(cancellationToken);

        return new ConfirmTicketResult(passToken);
    }
}

// ── Validate Ticket (Host Scanner) ──

public sealed record ValidateP2pTicketCommand(Guid EventId, string QrPayload) : IRequest<P2pTicketValidationResponse>;

public sealed record P2pTicketValidationResponse(
    bool IsValid,
    string BuyerName,
    string Message,
    bool IsDuplicate = false,
    string? PreviousScanAt = null);

public sealed class ValidateP2pTicketHandler : IRequestHandler<ValidateP2pTicketCommand, P2pTicketValidationResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ValidateP2pTicketHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<P2pTicketValidationResponse> Handle(ValidateP2pTicketCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Verify the current user is the host of this event
        var evt = await _context.P2pEvents
            .FirstOrDefaultAsync(e => e.Id == request.EventId && e.HostUserId == userId, cancellationToken)
            ?? throw new UnauthorizedAccessException("You are not the host of this event.");

        if (string.IsNullOrWhiteSpace(request.QrPayload))
            return new P2pTicketValidationResponse(false, string.Empty, "Empty QR payload.");

        var ticket = await _context.P2pEventTickets
            .FirstOrDefaultAsync(t => t.PassToken == request.QrPayload && t.P2pEventId == request.EventId, cancellationToken);

        if (ticket is null)
            return new P2pTicketValidationResponse(false, string.Empty, "Unknown ticket.");

        if (ticket.PaymentStatus != PaymentStatus.Captured)
            return new P2pTicketValidationResponse(false, string.Empty, "Payment not captured.");

        if (ticket.Status == "Refunded")
            return new P2pTicketValidationResponse(false, string.Empty, "Ticket has been refunded.");

        if (ticket.Status == "CheckedIn")
            return new P2pTicketValidationResponse(false, string.Empty, "Already checked in.", IsDuplicate: true, PreviousScanAt: ticket.CheckedInAt?.ToString("o"));

        // Check in the guest
        ticket.CheckIn();

        var buyer = await _context.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == ticket.BuyerUserId, cancellationToken);

        await _context.SaveChangesAsync(cancellationToken);

        return new P2pTicketValidationResponse(true, buyer?.Name ?? "Guest", "Valid ticket. Welcome!");
    }
}

// ── Cancel Event ──

public sealed record CancelP2pEventCommand(Guid EventId) : IRequest<Unit>;

public sealed class CancelP2pEventCommandHandler : IRequestHandler<CancelP2pEventCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IPaymentGateway _paymentGateway;

    public CancelP2pEventCommandHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IPaymentGateway paymentGateway)
    {
        _context = context;
        _currentUser = currentUser;
        _paymentGateway = paymentGateway;
    }

    public async Task<Unit> Handle(CancelP2pEventCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var evt = await _context.P2pEvents
            .FirstOrDefaultAsync(e => e.Id == request.EventId && e.HostUserId == userId, cancellationToken)
            ?? throw new UnauthorizedAccessException("Event not found or not owned by user.");

        evt.Cancel();

        // Refund all active tickets
        var tickets = await _context.P2pEventTickets
            .Where(t => t.P2pEventId == request.EventId && t.Status == "Active" && t.PaymentStatus == PaymentStatus.Captured)
            .ToListAsync(cancellationToken);

        foreach (var ticket in tickets)
        {
            ticket.Refund();
            evt.DecrementTickets();

            // Refund via payment gateway
            if (!string.IsNullOrWhiteSpace(ticket.PaymentReference) && ticket.PricePaid > 0)
            {
                _ = await _paymentGateway.RefundAsync(
                    ticket.PaymentReference, ticket.PricePaid, "Event cancelled", cancellationToken);
            }
        }

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

// ── Get Attendees (Host) ──

public sealed record GetP2pEventAttendeesQuery(Guid EventId) : IRequest<IReadOnlyList<AttendeeDto>>;

public sealed record AttendeeDto(
    Guid TicketId,
    string BuyerName,
    string BuyerPhone,
    decimal PricePaid,
    string Status,
    DateTimeOffset? CheckedInAt,
    DateTimeOffset PurchasedAt);

public sealed class GetP2pEventAttendeesHandler : IRequestHandler<GetP2pEventAttendeesQuery, IReadOnlyList<AttendeeDto>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetP2pEventAttendeesHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<AttendeeDto>> Handle(GetP2pEventAttendeesQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Verify host
        var isHost = await _context.P2pEvents
            .AnyAsync(e => e.Id == request.EventId && e.HostUserId == userId, cancellationToken);
        if (!isHost)
            throw new UnauthorizedAccessException("You are not the host of this event.");

        var tickets = await _context.P2pEventTickets
            .AsNoTracking()
            .Where(t => t.P2pEventId == request.EventId)
            .OrderByDescending(t => t.PurchasedAt)
            .ToListAsync(cancellationToken);

        var buyerIds = tickets.Select(t => t.BuyerUserId).Distinct().ToList();
        var buyers = await _context.Users
            .AsNoTracking()
            .Where(u => buyerIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, cancellationToken);

        return tickets.Select(t =>
        {
            buyers.TryGetValue(t.BuyerUserId, out var buyer);
            return new AttendeeDto(
                t.Id,
                buyer?.Name ?? "Unknown",
                buyer?.Phone ?? string.Empty,
                t.PricePaid,
                t.Status,
                t.CheckedInAt,
                t.PurchasedAt);
        }).ToList();
    }
}

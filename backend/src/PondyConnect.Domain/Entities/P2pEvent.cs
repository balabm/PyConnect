namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// A peer-to-peer (user-hosted) private event. Any authenticated user
/// can create an event, set an entry price (free or paid), capacity limit,
/// and share a URL. The backend holds ticket funds, takes a flat 5%
/// platform fee, and routes 95% to the host's PY Wallet.
/// </summary>
public sealed class P2pEvent : BaseEntity
{
    public Guid HostUserId { get; private set; }

    public string Title { get; private set; } = string.Empty;

    /// <summary>
    /// URL-safe unique identifier for deep-link sharing
    /// (e.g. "auroville-sunset-mix-a1b2c3").
    /// </summary>
    public string Slug { get; private set; } = string.Empty;

    public string? Description { get; private set; }

    /// <summary>
    /// What's offered at the event (e.g. "Pool access, BYOB, techno DJ").
    /// </summary>
    public string? WhatsOffered { get; private set; }

    public DateTimeOffset StartsAt { get; private set; }

    public DateTimeOffset EndsAt { get; private set; }

    public GeoLocation Location { get; private set; } = GeoLocation.Zero;

    public string? Address { get; private set; }

    /// <summary>
    /// Entry price in INR. 0 means free RSVP.
    /// </summary>
    public decimal EntryPrice { get; private set; }

    public int CapacityLimit { get; private set; }

    public int TicketsSold { get; private set; }

    public P2pEventStatus Status { get; private set; } = P2pEventStatus.Draft;

    public string? ImageUrl { get; private set; }

    /// <summary>
    /// Platform fee percentage taken from each ticket sale (default 5%).
    /// </summary>
    public decimal PlatformFeePercent { get; private set; } = 5m;

    private P2pEvent()
    {
        // EF Core constructor.
    }

    public static P2pEvent Create(
        Guid hostUserId,
        string title,
        string slug,
        DateTimeOffset startsAt,
        DateTimeOffset endsAt,
        GeoLocation location,
        decimal entryPrice = 0m,
        int capacityLimit = 50,
        string? description = null,
        string? whatsOffered = null,
        string? address = null,
        string? imageUrl = null,
        decimal platformFeePercent = 5m)
    {
        if (hostUserId == Guid.Empty)
            throw new ArgumentException("Host user ID is required.", nameof(hostUserId));
        ArgumentException.ThrowIfNullOrWhiteSpace(title);
        ArgumentException.ThrowIfNullOrWhiteSpace(slug);
        if (startsAt < DateTimeOffset.UtcNow.AddMinutes(-5))
            throw new ArgumentException("Event start must be in the near future.", nameof(startsAt));
        if (endsAt <= startsAt)
            throw new ArgumentException("Event end must be after start.", nameof(endsAt));
        ArgumentOutOfRangeException.ThrowIfNegative(entryPrice, nameof(entryPrice));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(capacityLimit, nameof(capacityLimit));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(platformFeePercent, nameof(platformFeePercent));

        return new P2pEvent
        {
            HostUserId = hostUserId,
            Title = title,
            Slug = slug,
            StartsAt = startsAt,
            EndsAt = endsAt,
            Location = location,
            EntryPrice = entryPrice,
            CapacityLimit = capacityLimit,
            Description = description,
            WhatsOffered = whatsOffered,
            Address = address,
            ImageUrl = imageUrl,
            PlatformFeePercent = platformFeePercent
        };
    }

    public void Publish()
    {
        if (Status != P2pEventStatus.Draft)
            throw new InvalidOperationException("Only draft events can be published.");
        Status = P2pEventStatus.Published;
        MarkUpdated();
    }

    public void MarkSoldOut()
    {
        if (Status != P2pEventStatus.Published)
            throw new InvalidOperationException("Only published events can be marked sold out.");
        Status = P2pEventStatus.SoldOut;
        MarkUpdated();
    }

    public void Complete()
    {
        if (Status is P2pEventStatus.Cancelled)
            throw new InvalidOperationException("A cancelled event cannot be completed.");
        Status = P2pEventStatus.Completed;
        MarkUpdated();
    }

    public void Cancel()
    {
        if (Status is P2pEventStatus.Completed or P2pEventStatus.Cancelled)
            throw new InvalidOperationException("Event already completed or cancelled.");
        Status = P2pEventStatus.Cancelled;
        MarkUpdated();
    }

    public void IncrementTickets(int count = 1)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(count, nameof(count));
        if (TicketsSold + count > CapacityLimit)
            throw new InvalidOperationException("Cannot sell more tickets than the capacity limit.");
        TicketsSold += count;
        if (TicketsSold >= CapacityLimit && Status == P2pEventStatus.Published)
            Status = P2pEventStatus.SoldOut;
        MarkUpdated();
    }

    public void DecrementTickets(int count = 1)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(count, nameof(count));
        if (TicketsSold < count)
            throw new InvalidOperationException("Cannot decrement tickets below zero.");
        TicketsSold -= count;
        if (Status == P2pEventStatus.SoldOut && TicketsSold < CapacityLimit)
            Status = P2pEventStatus.Published;
        MarkUpdated();
    }
}

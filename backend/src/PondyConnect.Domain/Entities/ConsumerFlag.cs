namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Records a fraud-prevention flag against a consumer. Flags can impose a
/// shadow-ban (de-prioritised in dispatch without the consumer knowing) and/or
/// a Cash-on-Delivery restriction. Temporary flags expire automatically via
/// <see cref="ExpiresAt"/>; permanent flags leave it null.
/// </summary>
public sealed class ConsumerFlag : BaseEntity
{
    /// <summary>
    /// The flagged consumer's identifier (user ID or phone number).
    /// </summary>
    public string ConsumerId { get; private set; } = string.Empty;

    public ConsumerFlagType FlagType { get; private set; }

    public string Reason { get; private set; } = string.Empty;

    /// <summary>
    /// When true, the consumer is shadow-banned (de-prioritised in dispatch
    /// and matching without an explicit notification).
    /// </summary>
    public bool ShadowBanned { get; private set; }

    /// <summary>
    /// When true, the consumer cannot place Cash-on-Delivery orders.
    /// </summary>
    public bool CodRestricted { get; private set; }

    /// <summary>
    /// When set, the flag is temporary and expires at this time. Null means
    /// the flag is permanent until manually removed.
    /// </summary>
    public DateTimeOffset? ExpiresAt { get; private set; }

    private ConsumerFlag()
    {
    }

    public static ConsumerFlag Create(
        string consumerId,
        ConsumerFlagType flagType,
        string reason,
        bool shadowBanned = false,
        bool codRestricted = false,
        DateTimeOffset? expiresAt = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(consumerId);
        ArgumentException.ThrowIfNullOrWhiteSpace(reason);

        return new ConsumerFlag
        {
            ConsumerId = consumerId,
            FlagType = flagType,
            Reason = reason,
            ShadowBanned = shadowBanned,
            CodRestricted = codRestricted,
            ExpiresAt = expiresAt,
        };
    }

    /// <summary>
    /// Returns true if this flag is currently active (not expired).
    /// </summary>
    public bool IsActive => !ExpiresAt.HasValue || ExpiresAt.Value > DateTimeOffset.UtcNow;
}

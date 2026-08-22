namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A chargeback dispute raised when a consumer issues a credit card
/// chargeback via their bank. The platform auto-generates an evidence
/// dossier containing order receipts, GPS logs, and delivery photos
/// to contest the chargeback.
/// </summary>
public sealed class ChargebackDispute : BaseEntity
{
    public Guid PaymentId { get; private set; }

    public Guid UserId { get; private set; }

    public Guid? OrderId { get; private set; }

    public string? OrderType { get; private set; }

    /// <summary>
    /// The amount being chargebacked by the consumer's bank.
    /// </summary>
    public decimal ChargebackAmount { get; private set; }

    /// <summary>
    /// The dispute reference from the payment provider/bank.
    /// </summary>
    public string? ProviderDisputeId { get; private set; }

    public ChargebackStatus Status { get; private set; } = ChargebackStatus.Open;

    /// <summary>
    /// JSON array of evidence URLs (receipts, photos, GPS logs).
    /// </summary>
    public string? EvidenceUrlsJson { get; private set; }

    /// <summary>
    /// Human-readable evidence summary for the admin dashboard.
    /// </summary>
    public string? EvidenceSummary { get; private set; }

    /// <summary>
    /// Whether the user's account has been frozen pending resolution.
    /// </summary>
    public bool AccountFrozen { get; private set; }

    public DateTimeOffset? ResolvedAt { get; private set; }

    public string? ResolutionNote { get; private set; }

    private ChargebackDispute()
    {
    }

    public static ChargebackDispute Create(
        Guid paymentId,
        Guid userId,
        decimal chargebackAmount,
        Guid? orderId = null,
        string? orderType = null,
        string? providerDisputeId = null)
    {
        if (paymentId == Guid.Empty)
            throw new ArgumentException("Payment ID is required.", nameof(paymentId));
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(chargebackAmount, nameof(chargebackAmount));

        return new ChargebackDispute
        {
            PaymentId = paymentId,
            UserId = userId,
            OrderId = orderId,
            OrderType = orderType,
            ChargebackAmount = chargebackAmount,
            ProviderDisputeId = providerDisputeId,
            Status = ChargebackStatus.Open,
            AccountFrozen = true
        };
    }

    /// <summary>
    /// Attaches the auto-generated evidence dossier to the dispute.
    /// </summary>
    public void AttachEvidence(string evidenceUrlsJson, string evidenceSummary)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(evidenceUrlsJson);
        ArgumentException.ThrowIfNullOrWhiteSpace(evidenceSummary);
        EvidenceUrlsJson = evidenceUrlsJson;
        EvidenceSummary = evidenceSummary;
        MarkUpdated();
    }

    /// <summary>
    /// Marks the chargeback as won (evidence accepted by bank).
    /// Unfreezes the user's account.
    /// </summary>
    public void MarkWon(string note)
    {
        Status = ChargebackStatus.Won;
        AccountFrozen = false;
        ResolvedAt = DateTimeOffset.UtcNow;
        ResolutionNote = note;
        MarkUpdated();
    }

    /// <summary>
    /// Marks the chargeback as lost (bank sided with consumer).
    /// Unfreezes the user's account but the amount is lost.
    /// </summary>
    public void MarkLost(string note)
    {
        Status = ChargebackStatus.Lost;
        AccountFrozen = false;
        ResolvedAt = DateTimeOffset.UtcNow;
        ResolutionNote = note;
        MarkUpdated();
    }

    public void UnfreezeAccount()
    {
        AccountFrozen = false;
        MarkUpdated();
    }
}

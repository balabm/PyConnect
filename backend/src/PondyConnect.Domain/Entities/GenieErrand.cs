namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A Genie Engine custom errand request. A consumer types a free-text
/// errand (e.g. "Pick up my laundry from Auroville") and an auth-hold
/// is placed on their card for the captain to fulfil. The captain
/// accepts, starts progress, and completes the errand with the actual
/// cost (captured from the auth-hold).
/// </summary>
public sealed class GenieErrand : BaseEntity
{
    public Guid UserId { get; private set; }

    /// <summary>
    /// Free-text description of the errand the consumer wants fulfilled.
    /// </summary>
    public string Description { get; private set; } = string.Empty;

    public string? PickupAddress { get; private set; }

    public double? PickupLat { get; private set; }

    public double? PickupLng { get; private set; }

    public string? DropoffAddress { get; private set; }

    public double? DropoffLat { get; private set; }

    public double? DropoffLng { get; private set; }

    /// <summary>
    /// Consumer's estimated cost for the errand in INR.
    /// </summary>
    public decimal EstimatedCost { get; private set; }

    /// <summary>
    /// Auth-hold amount placed on the consumer's card (>= EstimatedCost).
    /// Captured on completion with the actual cost.
    /// </summary>
    public decimal AuthHoldAmount { get; private set; }

    public GenieErrandStatus Status { get; private set; } = GenieErrandStatus.Draft;

    /// <summary>
    /// The captain (driver) who accepted the errand.
    /// </summary>
    public Guid? CaptainId { get; private set; }

    /// <summary>
    /// Actual cost charged on completion (captured from the auth-hold).
    /// </summary>
    public decimal? ActualCost { get; private set; }

    public string? RazorpayOrderId { get; private set; }

    public string? RazorpayPaymentId { get; private set; }

    private GenieErrand()
    {
        // EF Core constructor.
    }

    public static GenieErrand Create(
        Guid userId,
        string description,
        decimal estimatedCost,
        decimal authHoldAmount,
        string? pickupAddress = null,
        double? pickupLat = null,
        double? pickupLng = null,
        string? dropoffAddress = null,
        double? dropoffLat = null,
        double? dropoffLng = null)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        ArgumentException.ThrowIfNullOrWhiteSpace(description);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(estimatedCost, nameof(estimatedCost));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(authHoldAmount, nameof(authHoldAmount));
        if (authHoldAmount < estimatedCost)
            throw new ArgumentException("Auth-hold amount must be at least the estimated cost.", nameof(authHoldAmount));

        return new GenieErrand
        {
            UserId = userId,
            Description = description,
            EstimatedCost = estimatedCost,
            AuthHoldAmount = authHoldAmount,
            PickupAddress = pickupAddress,
            PickupLat = pickupLat,
            PickupLng = pickupLng,
            DropoffAddress = dropoffAddress,
            DropoffLat = dropoffLat,
            DropoffLng = dropoffLng,
            Status = GenieErrandStatus.Posted
        };
    }

    /// <summary>
    /// Captain accepts the posted errand.
    /// </summary>
    public void Accept(Guid captainId)
    {
        if (Status != GenieErrandStatus.Posted)
            throw new InvalidOperationException("Only posted errands can be accepted.");
        if (captainId == Guid.Empty)
            throw new ArgumentException("Captain ID is required.", nameof(captainId));

        CaptainId = captainId;
        Status = GenieErrandStatus.Accepted;
        MarkUpdated();
    }

    /// <summary>
    /// Captain starts progress on the accepted errand.
    /// </summary>
    public void StartProgress()
    {
        if (Status != GenieErrandStatus.Accepted)
            throw new InvalidOperationException("Only accepted errands can be started.");

        Status = GenieErrandStatus.InProgress;
        MarkUpdated();
    }

    /// <summary>
    /// Captain completes the errand with the actual cost, captured from
    /// the auth-hold.
    /// </summary>
    public void Complete(decimal actualCost, string? razorpayOrderId = null, string? razorpayPaymentId = null)
    {
        if (Status != GenieErrandStatus.InProgress)
            throw new InvalidOperationException("Only in-progress errands can be completed.");
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(actualCost, nameof(actualCost));

        ActualCost = actualCost;
        if (!string.IsNullOrWhiteSpace(razorpayOrderId))
            RazorpayOrderId = razorpayOrderId;
        if (!string.IsNullOrWhiteSpace(razorpayPaymentId))
            RazorpayPaymentId = razorpayPaymentId;
        Status = GenieErrandStatus.Completed;
        MarkUpdated();
    }

    /// <summary>
    /// Owner cancels the errand. Only draft or posted errands can be
    /// cancelled by the owner.
    /// </summary>
    public void Cancel()
    {
        if (Status is not (GenieErrandStatus.Draft or GenieErrandStatus.Posted))
            throw new InvalidOperationException("Only draft or posted errands can be cancelled.");

        Status = GenieErrandStatus.Cancelled;
        MarkUpdated();
    }

    /// <summary>
    /// Sets the Razorpay order ID after the auth-hold order is created.
    /// Called by the controller after creating the Razorpay order.
    /// </summary>
    public void SetRazorpayOrderId(string? orderId)
    {
        if (!string.IsNullOrWhiteSpace(orderId))
            RazorpayOrderId = orderId;
        MarkUpdated();
    }

    /// <summary>
    /// Sets the Razorpay payment ID after the consumer completes checkout.
    /// Called by the frontend after Razorpay payment success.
    /// </summary>
    public void SetRazorpayPaymentId(string? paymentId)
    {
        if (!string.IsNullOrWhiteSpace(paymentId))
            RazorpayPaymentId = paymentId;
        MarkUpdated();
    }
}

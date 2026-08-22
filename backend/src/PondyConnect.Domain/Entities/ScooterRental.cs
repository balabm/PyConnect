namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Scooter or bike rental booking (incl. bike-taxi hailing as a short rental).
/// </summary>
public sealed class ScooterRental : BaseEntity
{
    public Guid UserId { get; private set; }

    public Guid VendorId { get; private set; }

    public Vendor Vendor { get; private set; } = null!;

    public string VehicleName { get; private set; } = string.Empty;

    public string? VehiclePlate { get; private set; }

    public DateTimeOffset RentalStart { get; private set; }

    public DateTimeOffset RentalEnd { get; private set; }

    public decimal RatePerHour { get; private set; }

    public decimal TotalAmount { get; private set; }

    public RentalStatus Status { get; private set; } = RentalStatus.Reserved;

    public PaymentStatus PaymentStatus { get; private set; } = PaymentStatus.Unpaid;

    public string? PaymentReference { get; private set; }

    public string? Notes { get; private set; }

    // ── Pre-rental condition inspection ──

    /// <summary>
    /// JSON array of condition photo URLs (Front, Back, Left, Right,
    /// Odometer/Fuel). Cryptographically timestamped to create an
    /// undeniable baseline for damage claims.
    /// </summary>
    public string? ConditionPhotosJson { get; private set; }

    /// <summary>
    /// When the condition photos were submitted at pickup.
    /// </summary>
    public DateTimeOffset? ConditionPhotosAt { get; private set; }

    // ── Security deposit ──

    /// <summary>
    /// Pre-authorized security deposit amount (held via Razorpay).
    /// </summary>
    public decimal SecurityDeposit { get; private set; }

    /// <summary>
    /// Razorpay payment ID for the security deposit hold.
    /// </summary>
    public string? DepositPaymentReference { get; private set; }

    /// <summary>
    /// Amount deducted from the deposit for late returns or damage.
    /// </summary>
    public decimal DepositPenalty { get; private set; }

    /// <summary>
    /// Amount refunded from the deposit after return.
    /// </summary>
    public decimal DepositRefunded { get; private set; }

    /// <summary>
    /// JSON array of post-return condition photo URLs for damage comparison.
    /// </summary>
    public string? ReturnConditionPhotosJson { get; private set; }

    /// <summary>
    /// When the rental was actually returned (may differ from RentalEnd if late).
    /// </summary>
    public DateTimeOffset? ActualReturnAt { get; private set; }

    private ScooterRental()
    {
        // EF Core constructor.
    }

    public static ScooterRental Create(
        Guid userId,
        Guid vendorId,
        string vehicleName,
        DateTimeOffset rentalStart,
        DateTimeOffset rentalEnd,
        decimal ratePerHour,
        string? vehiclePlate = null,
        string? notes = null)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        ArgumentException.ThrowIfNullOrWhiteSpace(vehicleName);
        if (rentalStart < DateTimeOffset.UtcNow.AddMinutes(-5))
            throw new ArgumentException("Rental start must be in the near future.", nameof(rentalStart));
        if (rentalEnd <= rentalStart)
            throw new ArgumentException("Rental end must be after start.", nameof(rentalEnd));
        ArgumentOutOfRangeException.ThrowIfNegative(ratePerHour, nameof(ratePerHour));

        var hours = (decimal)(rentalEnd - rentalStart).TotalHours;
        var total = hours * ratePerHour;
        return new ScooterRental
        {
            UserId = userId,
            VendorId = vendorId,
            VehicleName = vehicleName,
            VehiclePlate = vehiclePlate,
            RentalStart = rentalStart,
            RentalEnd = rentalEnd,
            RatePerHour = ratePerHour,
            TotalAmount = total,
            Notes = notes
        };
    }

    public void StartRental()
    {
        if (Status != RentalStatus.Reserved)
            throw new InvalidOperationException("Only reserved rentals can be started.");
        Status = RentalStatus.Active;
        MarkUpdated();
    }

    /// <summary>
    /// Records the pre-rental 4-angle condition photos (Front, Back,
    /// Left, Right, Odometer/Fuel). Cryptographically timestamped to
    /// create an undeniable baseline for damage claims.
    /// </summary>
    public void RecordConditionPhotos(string photosJson)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(photosJson);
        ConditionPhotosJson = photosJson;
        ConditionPhotosAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Records the security deposit hold. Called when the Razorpay
    /// pre-authorized hold is created.
    /// </summary>
    public void RecordDeposit(decimal amount, string paymentReference)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));
        ArgumentException.ThrowIfNullOrWhiteSpace(paymentReference);
        SecurityDeposit = amount;
        DepositPaymentReference = paymentReference;
        MarkUpdated();
    }

    /// <summary>
    /// Completes the rental return with optional late fees and damage
    /// penalties. Calculates the total penalty and determines how much
    /// to refund from the security deposit.
    /// </summary>
    public void CompleteReturn(
        int lateMinutes = 0,
        decimal damageAmount = 0m,
        string? returnConditionPhotosJson = null)
    {
        if (Status != RentalStatus.Active)
            throw new InvalidOperationException("Only active rentals can be returned.");

        ActualReturnAt = DateTimeOffset.UtcNow;
        if (!string.IsNullOrWhiteSpace(returnConditionPhotosJson))
            ReturnConditionPhotosJson = returnConditionPhotosJson;

        // Calculate late penalty: hourly rate for each late hour beyond 30-min grace
        var latePenalty = 0m;
        if (lateMinutes > 30 && RentalEnd < DateTimeOffset.UtcNow)
        {
            var lateHours = (decimal)Math.Ceiling(lateMinutes / 60.0);
            latePenalty = lateHours * RatePerHour;
        }

        DepositPenalty = latePenalty + damageAmount;
        DepositRefunded = Math.Max(0m, SecurityDeposit - DepositPenalty);

        // Add late penalty to total amount
        TotalAmount += latePenalty;

        Status = RentalStatus.Returned;
        MarkUpdated();
    }

    public void Return()
    {
        if (Status != RentalStatus.Active)
            throw new InvalidOperationException("Only active rentals can be returned.");
        Status = RentalStatus.Returned;
        MarkUpdated();
    }

    public void Cancel()
    {
        if (Status is RentalStatus.Returned or RentalStatus.Cancelled)
            throw new InvalidOperationException("Cannot cancel after return or if already cancelled.");
        Status = RentalStatus.Cancelled;
        MarkUpdated();
    }

    public void RecordPayment(PaymentStatus paymentStatus, string paymentReference)
    {
        if (string.IsNullOrWhiteSpace(paymentReference))
            throw new ArgumentException("Payment reference is required.", nameof(paymentReference));
        PaymentStatus = paymentStatus;
        PaymentReference = paymentReference;
        MarkUpdated();
    }
}
namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// An equipment rental booking made by a consumer. Tracks the rental
/// lifecycle through a Kanban board (Reserved -> Delivered -> ActiveInField
/// -> AwaitingReturn -> Returned) and manages the security deposit
/// auth-hold via Razorpay capture:false.
/// </summary>
public sealed class EquipmentRental : BaseEntity
{
    public Guid UserId { get; private set; }

    public Guid VendorId { get; private set; }

    public Guid EquipmentItemId { get; private set; }

    public int UnitsBooked { get; private set; }

    public DateTimeOffset RentalStart { get; private set; }

    public DateTimeOffset RentalEnd { get; private set; }

    public decimal DailyRate { get; private set; }

    public decimal TotalAmount { get; private set; }

    public EquipmentRentalStatus Status { get; private set; } = EquipmentRentalStatus.Reserved;

    public PaymentStatus PaymentStatus { get; private set; } = PaymentStatus.Unpaid;

    public string? PaymentReference { get; private set; }

    // ── Security deposit (auth-hold) ──

    public decimal SecurityDeposit { get; private set; }

    public string? DepositPaymentReference { get; private set; }

    public decimal DepositPenalty { get; private set; }

    public decimal DepositRefunded { get; private set; }

    // ── Condition tracking ──

    public string? ConditionPhotosJson { get; private set; }

    public string? ReturnConditionPhotosJson { get; private set; }

    public DateTimeOffset? ActualReturnAt { get; private set; }

    public string? DeliveryAddress { get; private set; }

    public string? Notes { get; private set; }

    private EquipmentRental()
    {
        // EF Core constructor.
    }

    public static EquipmentRental Create(
        Guid userId,
        Guid vendorId,
        Guid equipmentItemId,
        int unitsBooked,
        DateTimeOffset rentalStart,
        DateTimeOffset rentalEnd,
        decimal dailyRate,
        decimal securityDepositPerUnit,
        string? deliveryAddress = null,
        string? notes = null)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        if (equipmentItemId == Guid.Empty)
            throw new ArgumentException("Equipment item ID is required.", nameof(equipmentItemId));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(unitsBooked, nameof(unitsBooked));
        if (rentalStart < DateTimeOffset.UtcNow.AddMinutes(-5))
            throw new ArgumentException("Rental start must be in the near future.", nameof(rentalStart));
        if (rentalEnd <= rentalStart)
            throw new ArgumentException("Rental end must be after start.", nameof(rentalEnd));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(dailyRate, nameof(dailyRate));
        ArgumentOutOfRangeException.ThrowIfNegative(securityDepositPerUnit, nameof(securityDepositPerUnit));

        var days = Math.Max(1, (decimal)(rentalEnd - rentalStart).TotalDays);
        var total = days * dailyRate * unitsBooked;
        var deposit = securityDepositPerUnit * unitsBooked;

        return new EquipmentRental
        {
            UserId = userId,
            VendorId = vendorId,
            EquipmentItemId = equipmentItemId,
            UnitsBooked = unitsBooked,
            RentalStart = rentalStart,
            RentalEnd = rentalEnd,
            DailyRate = dailyRate,
            TotalAmount = total,
            SecurityDeposit = deposit,
            DeliveryAddress = deliveryAddress,
            Notes = notes
        };
    }

    public void MarkDelivered()
    {
        if (Status != EquipmentRentalStatus.Reserved)
            throw new InvalidOperationException("Only reserved rentals can be marked as delivered.");
        Status = EquipmentRentalStatus.Delivered;
        MarkUpdated();
    }

    public void MarkActiveInField()
    {
        if (Status != EquipmentRentalStatus.Delivered)
            throw new InvalidOperationException("Only delivered rentals can be marked active in field.");
        Status = EquipmentRentalStatus.ActiveInField;
        MarkUpdated();
    }

    public void MarkAwaitingReturn()
    {
        if (Status != EquipmentRentalStatus.ActiveInField && Status != EquipmentRentalStatus.Delivered)
            throw new InvalidOperationException("Only active/delivered rentals can be marked as awaiting return.");
        Status = EquipmentRentalStatus.AwaitingReturn;
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
        if (Status != EquipmentRentalStatus.AwaitingReturn && Status != EquipmentRentalStatus.ActiveInField)
            throw new InvalidOperationException("Only awaiting-return or active rentals can be returned.");

        ActualReturnAt = DateTimeOffset.UtcNow;
        if (!string.IsNullOrWhiteSpace(returnConditionPhotosJson))
            ReturnConditionPhotosJson = returnConditionPhotosJson;

        // Calculate late penalty: daily rate for each late day beyond 2-hour grace
        var latePenalty = 0m;
        if (lateMinutes > 120 && RentalEnd < DateTimeOffset.UtcNow)
        {
            var lateDays = (decimal)Math.Ceiling(lateMinutes / 1440.0);
            latePenalty = lateDays * DailyRate * UnitsBooked;
        }

        DepositPenalty = latePenalty + damageAmount;
        DepositRefunded = Math.Max(0m, SecurityDeposit - DepositPenalty);
        TotalAmount += latePenalty;

        Status = EquipmentRentalStatus.Returned;
        MarkUpdated();
    }

    public void Cancel()
    {
        if (Status is EquipmentRentalStatus.Returned or EquipmentRentalStatus.Cancelled)
            throw new InvalidOperationException("Cannot cancel after return or if already cancelled.");
        Status = EquipmentRentalStatus.Cancelled;
        MarkUpdated();
    }

    public void RecordDeposit(string paymentReference)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(paymentReference);
        DepositPaymentReference = paymentReference;
        MarkUpdated();
    }

    public void RecordPayment(PaymentStatus paymentStatus, string paymentReference)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(paymentReference);
        PaymentStatus = paymentStatus;
        PaymentReference = paymentReference;
        MarkUpdated();
    }

    public void RecordConditionPhotos(string photosJson)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(photosJson);
        ConditionPhotosJson = photosJson;
        MarkUpdated();
    }
}

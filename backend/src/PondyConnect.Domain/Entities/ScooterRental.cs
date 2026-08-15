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
namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

public sealed class DriverLedgerEntry : BaseEntity
{
    public Guid DriverId { get; private set; }

    public decimal Amount { get; private set; }

    public LedgerTransactionType TransactionType { get; private set; }

    public string? Reference { get; private set; }

    private DriverLedgerEntry()
    {
    }

    public static DriverLedgerEntry Create(
        Guid driverId,
        decimal amount,
        LedgerTransactionType transactionType,
        string? reference = null)
    {
        if (driverId == Guid.Empty)
            throw new ArgumentException("Driver ID is required.", nameof(driverId));

        return new DriverLedgerEntry
        {
            DriverId = driverId,
            Amount = amount,
            TransactionType = transactionType,
            Reference = reference
        };
    }
}

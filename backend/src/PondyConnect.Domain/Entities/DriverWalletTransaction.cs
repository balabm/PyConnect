namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A single ledger entry against a <see cref="DriverWallet"/>. Positive
/// <see cref="Amount"/> values are credits (top-ups, settlements); negative
/// values are debits (commission deductions). <see cref="ReferenceId"/>
/// links back to the originating ride or order.
/// </summary>
public sealed class DriverWalletTransaction : BaseEntity
{
    public Guid WalletId { get; private set; }

    public DriverWalletTransactionType Type { get; private set; }

    public decimal Amount { get; private set; }

    public string Description { get; private set; } = string.Empty;

    public string? ReferenceId { get; private set; }

    public DriverWallet? Wallet { get; private set; }

    private DriverWalletTransaction()
    {
    }

    public static DriverWalletTransaction Create(
        Guid walletId,
        DriverWalletTransactionType type,
        decimal amount,
        string description,
        string? referenceId = null)
    {
        if (walletId == Guid.Empty)
            throw new ArgumentException("Wallet ID is required.", nameof(walletId));
        ArgumentException.ThrowIfNullOrWhiteSpace(description);

        return new DriverWalletTransaction
        {
            WalletId = walletId,
            Type = type,
            Amount = amount,
            Description = description,
            ReferenceId = referenceId
        };
    }
}

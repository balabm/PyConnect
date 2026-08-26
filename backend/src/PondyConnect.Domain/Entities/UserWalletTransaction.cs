namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A single ledger entry against a <see cref="UserWallet"/>. Positive
/// <see cref="Amount"/> values are credits (top-ups, promo credits, refunds);
/// negative values are debits (payments for orders, rides, rentals).
/// <see cref="ReferenceId"/> links back to the originating order or ride.
/// </summary>
public sealed class UserWalletTransaction : BaseEntity
{
    public Guid WalletId { get; private set; }

    public UserWalletTransactionType Type { get; private set; }

    public decimal Amount { get; private set; }

    public string Description { get; private set; } = string.Empty;

    public string? ReferenceId { get; private set; }

    public UserWallet? Wallet { get; private set; }

    private UserWalletTransaction()
    {
    }

    public static UserWalletTransaction Create(
        Guid walletId,
        UserWalletTransactionType type,
        decimal amount,
        string description,
        string? referenceId = null)
    {
        if (walletId == Guid.Empty)
            throw new ArgumentException("Wallet ID is required.", nameof(walletId));
        ArgumentException.ThrowIfNullOrWhiteSpace(description);

        return new UserWalletTransaction
        {
            WalletId = walletId,
            Type = type,
            Amount = amount,
            Description = description,
            ReferenceId = referenceId
        };
    }
}

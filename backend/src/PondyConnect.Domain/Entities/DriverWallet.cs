namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// Per-driver cash-collection ledger wallet. Tracks the running balance of
/// platform commission owed by the driver for Cash-on-Delivery rides/orders.
/// The balance can go negative (the driver owes the platform) down to the
/// <see cref="HardLimit"/>. When the balance reaches the hard limit the
/// wallet is suspended and the driver cannot go online until dues are settled.
/// </summary>
public sealed class DriverWallet : BaseEntity
{
    public Guid DriverId { get; private set; }

    public decimal Balance { get; private set; }

    public decimal HardLimit { get; private set; } = -1000.00m;

    public string Currency { get; private set; } = "INR";

    public bool Suspended { get; private set; }

    public DateTimeOffset? LastSettledAt { get; private set; }

    public Driver? Driver { get; private set; }

    private DriverWallet()
    {
    }

    public static DriverWallet Create(Guid driverId, decimal hardLimit = -1000.00m, string currency = "INR")
    {
        if (driverId == Guid.Empty)
            throw new ArgumentException("Driver ID is required.", nameof(driverId));

        return new DriverWallet
        {
            DriverId = driverId,
            Balance = 0m,
            HardLimit = hardLimit,
            Currency = currency
        };
    }

    /// <summary>
    /// Debits (subtracts) a commission amount from the wallet balance.
    /// Commission is the platform's cut from cash collected by the driver
    /// for COD rides/orders, so it reduces the balance (can go negative).
    /// </summary>
    public void Debit(decimal amount)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));
        Balance -= amount;
        MarkUpdated();
    }

    /// <summary>
    /// Credits (adds) a top-up or settlement amount to the wallet balance.
    /// Clears the suspended flag when the balance returns to >= 0.
    /// </summary>
    public void Credit(decimal amount)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));
        Balance += amount;
        if (Balance >= 0m)
            Suspended = false;
        MarkUpdated();
    }

    /// <summary>
    /// Suspends the wallet when the balance has reached or breached the
    /// hard limit. Returns true if the suspension state changed.
    /// </summary>
    public bool SuspendIfAtHardLimit()
    {
        if (Balance <= HardLimit && !Suspended)
        {
            Suspended = true;
            MarkUpdated();
            return true;
        }
        return false;
    }

    /// <summary>
    /// Records the last time the wallet was settled (payout / admin clearance).
    /// </summary>
    public void MarkSettled()
    {
        LastSettledAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }
}

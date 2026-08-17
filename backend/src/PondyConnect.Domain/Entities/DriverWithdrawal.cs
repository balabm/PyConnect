namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Tracks a driver's request to withdraw a positive wallet balance to their
/// linked bank account or UPI. Admins approve/reject; a payout is attempted
/// after approval.
/// </summary>
public sealed class DriverWithdrawal : BaseEntity
{
    public Guid DriverId { get; private set; }

    public Guid WalletId { get; private set; }

    public decimal Amount { get; private set; }

    public DriverWithdrawalStatus Status { get; private set; }

    public string? BankAccountNumber { get; private set; }

    public string? UpiId { get; private set; }

    public DateTimeOffset RequestedAt { get; private set; }

    public DateTimeOffset? ProcessedAt { get; private set; }

    public string? AdminNote { get; private set; }

    public Driver? Driver { get; private set; }

    public DriverWallet? Wallet { get; private set; }

    private DriverWithdrawal()
    {
    }

    public static DriverWithdrawal Create(
        Guid driverId,
        Guid walletId,
        decimal amount,
        string? bankAccountNumber = null,
        string? upiId = null)
    {
        if (driverId == Guid.Empty)
            throw new ArgumentException("Driver ID is required.", nameof(driverId));
        if (walletId == Guid.Empty)
            throw new ArgumentException("Wallet ID is required.", nameof(walletId));
        if (amount <= 0)
            throw new ArgumentOutOfRangeException(nameof(amount), "Amount must be greater than zero.");

        return new DriverWithdrawal
        {
            DriverId = driverId,
            WalletId = walletId,
            Amount = amount,
            Status = DriverWithdrawalStatus.Pending,
            BankAccountNumber = bankAccountNumber,
            UpiId = upiId,
            RequestedAt = DateTimeOffset.UtcNow
        };
    }

    public void Approve()
    {
        if (Status != DriverWithdrawalStatus.Pending)
            throw new InvalidOperationException("Only pending withdrawals can be approved.");

        Status = DriverWithdrawalStatus.Approved;
        MarkUpdated();
    }

    public void Reject(string? adminNote = null)
    {
        if (Status != DriverWithdrawalStatus.Pending)
            throw new InvalidOperationException("Only pending withdrawals can be rejected.");

        Status = DriverWithdrawalStatus.Rejected;
        AdminNote = adminNote;
        MarkUpdated();
    }

    public void MarkProcessed()
    {
        if (Status != DriverWithdrawalStatus.Approved)
            throw new InvalidOperationException("Only approved withdrawals can be marked as processed.");

        Status = DriverWithdrawalStatus.Processed;
        ProcessedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }
}

namespace PondyConnect.Domain.Enums;

/// <summary>
/// The kind of movement recorded against a driver's cash-collection wallet.
/// Commission debits the platform's cut from cash collected by the driver;
/// TopUp credits settled dues; Settlement records an admin/payout settlement;
/// Adjustment covers manual corrections.
/// </summary>
public enum DriverWalletTransactionType
{
    Commission = 1,
    TopUp = 2,
    Settlement = 3,
    Adjustment = 4,
    Withdrawal = 5
}

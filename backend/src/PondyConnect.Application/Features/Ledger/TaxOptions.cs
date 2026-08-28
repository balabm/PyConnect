namespace PondyConnect.Application.Features.Ledger;

/// <summary>
/// Configurable tax rates for the platform.
/// Bound to the "Pricing:Tax" section in appsettings.json.
/// </summary>
public sealed class TaxOptions
{
    /// <summary>GST rate applied to food orders (default 5%).</summary>
    public decimal FoodGstRate { get; set; } = 0.05m;

    /// <summary>GST rate applied to platform fees and commissions (default 18%).</summary>
    public decimal PlatformGstRate { get; set; } = 0.18m;

    /// <summary>TDS rate on vendor payouts (default 0.1%).</summary>
    public decimal TdsRate { get; set; } = 0.001m;

    /// <summary>TDS rate on certain vendor withdrawals (default 10%).</summary>
    public decimal VendorWithdrawalTdsRate { get; set; } = 0.1m;
}

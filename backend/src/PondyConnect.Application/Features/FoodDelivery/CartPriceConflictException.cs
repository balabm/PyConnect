namespace PondyConnect.Application.Features.FoodDelivery;

/// <summary>
/// Thrown when the client-submitted cart prices do not match the live
/// database prices at checkout time. The backend recalculates using current
/// menu prices and returns the live item prices so the client can update
/// the cart and prompt the user to review the new total.
/// </summary>
public sealed class CartPriceConflictException : Exception
{
    /// <summary>
    /// The live menu prices keyed by item name, as they currently exist in
    /// the database. The client should use these to update the cart.
    /// </summary>
    public IReadOnlyDictionary<string, decimal> LiveItemPrices { get; }

    /// <summary>
    /// The recalculated subtotal using live database prices.
    /// </summary>
    public decimal LiveSubTotal { get; }

    /// <summary>
    /// The recalculated grand total using live database prices, delivery
    /// fees, taxes, and platform fees.
    /// </summary>
    public decimal LiveTotalAmount { get; }

    public CartPriceConflictException(
        IReadOnlyDictionary<string, decimal> liveItemPrices,
        decimal liveSubTotal,
        decimal liveTotalAmount)
        : base("Menu prices have been updated by the restaurant. Please review your new total before paying.")
    {
        LiveItemPrices = liveItemPrices;
        LiveSubTotal = liveSubTotal;
        LiveTotalAmount = liveTotalAmount;
    }
}

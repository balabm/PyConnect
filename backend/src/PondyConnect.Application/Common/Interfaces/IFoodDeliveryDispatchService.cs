namespace PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Broadcasts a food delivery pickup offer to nearby online drivers via
/// SignalR (DriverHub). Called when a food order transitions to OutForDelivery.
/// </summary>
public interface IFoodDeliveryDispatchService
{
    /// <summary>
    /// Dispatch a food delivery offer to nearby online drivers.
    /// Returns the list of driver IDs the offer was sent to.
    /// </summary>
    Task<IReadOnlyList<Guid>> DispatchFoodOrderAsync(
        Guid foodOrderId,
        CancellationToken cancellationToken = default);
}

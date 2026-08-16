namespace PondyConnect.Application.Features.Fraud;

/// <summary>
/// Detects and records fraudulent consumer behaviour, applying shadow-bans
/// and Cash-on-Delivery restrictions when thresholds are breached.
/// </summary>
public interface IFraudDetectionService
{
    /// <summary>
    /// Records a post-assignment ride cancellation for the consumer and
    /// automatically applies a COD restriction if the consumer has cancelled
    /// 3 or more rides after driver assignment in the last 24 hours.
    /// </summary>
    /// <param name="consumerId">The consumer's user identifier (Guid as string).</param>
    /// <param name="rideId">The ride that was cancelled.</param>
    Task RecordCancellationAsync(string consumerId, string rideId);

    /// <summary>
    /// Evaluates the consumer's cancellation history and applies a
    /// shadow-ban if the high-cancellation threshold is met.
    /// </summary>
    Task EvaluateConsumerAsync(string consumerId);

    /// <summary>
    /// Returns true if the consumer is currently restricted from placing
    /// Cash-on-Delivery orders.
    /// </summary>
    Task<bool> IsCodRestrictedAsync(string consumerId);

    /// <summary>
    /// Returns true if the consumer is currently shadow-banned.
    /// </summary>
    Task<bool> IsShadowBannedAsync(string consumerId);
}

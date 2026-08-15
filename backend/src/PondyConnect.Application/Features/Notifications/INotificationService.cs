namespace PondyConnect.Application.Features.Notifications;

public interface INotificationService
{
    Task<bool> SendTargetedPushAsync(
        Guid userId,
        string title,
        string body,
        Dictionary<string, string>? dataPayload = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Sends a high-priority FCM data message that wakes the device even when
    /// the app is killed. Used for driver ride/delivery offer alerts.
    /// Sets Android priority to "high" and notification priority to "max"
    /// with a full-screen intent compatible payload.
    /// </summary>
    Task<bool> SendHighPriorityPushAsync(
        Guid userId,
        string title,
        string body,
        Dictionary<string, string>? dataPayload = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Sends a high-priority push notification to a vendor (partner app)
    /// by looking up the vendor's FCM device token. Used for new order alerts.
    /// </summary>
    Task<bool> SendPushToVendorAsync(
        Guid vendorId,
        string title,
        string body,
        Dictionary<string, string>? dataPayload = null,
        CancellationToken cancellationToken = default);
}

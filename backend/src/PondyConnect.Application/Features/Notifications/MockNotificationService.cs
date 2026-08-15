namespace PondyConnect.Application.Features.Notifications;

using Microsoft.Extensions.Logging;

public sealed class MockNotificationService : INotificationService
{
    private readonly ILogger<MockNotificationService> _logger;

    public MockNotificationService(ILogger<MockNotificationService> logger)
    {
        _logger = logger;
    }

    public Task<bool> SendTargetedPushAsync(
        Guid userId,
        string title,
        string body,
        Dictionary<string, string>? dataPayload = null,
        CancellationToken cancellationToken = default)
    {
#pragma warning disable CA1848
        var dataStr = dataPayload != null
            ? string.Join(", ", dataPayload.Select(kv => $"{kv.Key}={kv.Value}"))
            : "none";

        _logger.LogInformation(
            "[MockPush] UserId={UserId}, Title={Title}, Body={Body}, Data={Data}",
            userId, title, body, dataStr);
#pragma warning restore CA1848

        return Task.FromResult(true);
    }

    public Task<bool> SendHighPriorityPushAsync(
        Guid userId,
        string title,
        string body,
        Dictionary<string, string>? dataPayload = null,
        CancellationToken cancellationToken = default)
    {
#pragma warning disable CA1848
        _logger.LogInformation(
            "[MockPush:HIGH] UserId={UserId}, Title={Title}, Body={Body}",
            userId, title, body);
#pragma warning restore CA1848

        return Task.FromResult(true);
    }

    public Task<bool> SendPushToVendorAsync(
        Guid vendorId,
        string title,
        string body,
        Dictionary<string, string>? dataPayload = null,
        CancellationToken cancellationToken = default)
    {
#pragma warning disable CA1848
        _logger.LogInformation(
            "[MockPush:VENDOR] VendorId={VendorId}, Title={Title}, Body={Body}",
            vendorId, title, body);
#pragma warning restore CA1848

        return Task.FromResult(true);
    }
}

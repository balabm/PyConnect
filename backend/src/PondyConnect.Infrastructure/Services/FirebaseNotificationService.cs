namespace PondyConnect.Infrastructure.Services;

using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Infrastructure.Configuration;

public sealed class FirebaseNotificationService : INotificationService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<FirebaseNotificationService> _logger;
    private readonly FirebaseOptions _options;

    public FirebaseNotificationService(
        IApplicationDbContext context,
        ILogger<FirebaseNotificationService> logger,
        IOptions<FirebaseOptions> options)
    {
        _context = context;
        _logger = logger;
        _options = options.Value;

        if (FirebaseApp.DefaultInstance is null && _options.IsEnabled)
        {
            var credentialPath = _options.ServiceAccountPath;
            if (!string.IsNullOrWhiteSpace(credentialPath) && File.Exists(credentialPath))
            {
                FirebaseApp.Create(new AppOptions
                {
                    Credential = Google.Apis.Auth.OAuth2.GoogleCredential.FromFile(credentialPath),
                });
            }
        }
    }

    public async Task<bool> SendTargetedPushAsync(
        Guid userId,
        string title,
        string body,
        Dictionary<string, string>? dataPayload = null,
        CancellationToken cancellationToken = default)
    {
        var token = await _context.Users
            .Where(u => u.Id == userId)
            .Select(u => u.FcmDeviceToken)
            .FirstOrDefaultAsync(cancellationToken);

        if (string.IsNullOrWhiteSpace(token))
        {
#pragma warning disable CA1848
            _logger.LogWarning("No FCM token for user {UserId}", userId);
#pragma warning restore CA1848
            return false;
        }

        var message = new Message
        {
            Token = token,
            Notification = new Notification
            {
                Title = title,
                Body = body,
            },
            Data = dataPayload ?? new Dictionary<string, string>(),
        };

        try
        {
            var messaging = FirebaseMessaging.DefaultInstance;
            await messaging.SendAsync(message, cancellationToken);
            return true;
        }
        catch (FirebaseMessagingException ex) when (IsInvalidTokenError(ex))
        {
            await ClearUserTokenAsync(userId, cancellationToken);
            return false;
        }
        catch (Exception ex)
        {
#pragma warning disable CA1848
            _logger.LogError(ex, "Failed to send FCM push to user {UserId}", userId);
#pragma warning restore CA1848
            return false;
        }
    }

    public async Task<bool> SendHighPriorityPushAsync(
        Guid userId,
        string title,
        string body,
        Dictionary<string, string>? dataPayload = null,
        CancellationToken cancellationToken = default)
    {
        var token = await _context.Users
            .Where(u => u.Id == userId)
            .Select(u => u.FcmDeviceToken)
            .FirstOrDefaultAsync(cancellationToken);

        if (string.IsNullOrWhiteSpace(token))
        {
#pragma warning disable CA1848
            _logger.LogWarning("No FCM token for user {UserId}", userId);
#pragma warning restore CA1848
            return false;
        }

        var message = new Message
        {
            Token = token,
            Notification = new Notification
            {
                Title = title,
                Body = body,
            },
            Data = dataPayload ?? new Dictionary<string, string>(),
            Android = new AndroidConfig
            {
                Priority = Priority.High,
                Notification = new AndroidNotification
                {
                    Priority = NotificationPriority.MAX,
                    ChannelId = "ride_offers",
                    ClickAction = "FLUTTER_NOTIFICATION_CLICK",
                    DefaultSound = true,
                    NotificationCount = 1,
                    Tag = "ride_offer",
                },
            },
        };

        try
        {
            var messaging = FirebaseMessaging.DefaultInstance;
            await messaging.SendAsync(message, cancellationToken);
            return true;
        }
        catch (FirebaseMessagingException ex) when (IsInvalidTokenError(ex))
        {
            await ClearUserTokenAsync(userId, cancellationToken);
            return false;
        }
        catch (Exception ex)
        {
#pragma warning disable CA1848
            _logger.LogError(ex, "Failed to send high-priority FCM push to user {UserId}", userId);
#pragma warning restore CA1848
            return false;
        }
    }

    public async Task<bool> SendPushToVendorAsync(
        Guid vendorId,
        string title,
        string body,
        Dictionary<string, string>? dataPayload = null,
        CancellationToken cancellationToken = default)
    {
        var token = await _context.Vendors
            .Where(v => v.Id == vendorId)
            .Select(v => v.FcmDeviceToken)
            .FirstOrDefaultAsync(cancellationToken);

        if (string.IsNullOrWhiteSpace(token))
        {
#pragma warning disable CA1848
            _logger.LogWarning("No FCM token for vendor {VendorId}", vendorId);
#pragma warning restore CA1848
            return false;
        }

        var message = new Message
        {
            Token = token,
            Notification = new Notification
            {
                Title = title,
                Body = body,
            },
            Data = dataPayload ?? new Dictionary<string, string>(),
            Android = new AndroidConfig
            {
                Priority = Priority.High,
                Notification = new AndroidNotification
                {
                    Priority = NotificationPriority.MAX,
                    ChannelId = "new_orders",
                    ClickAction = "FLUTTER_NOTIFICATION_CLICK",
                    DefaultSound = true,
                    NotificationCount = 1,
                    Tag = "new_order",
                },
            },
        };

        try
        {
            var messaging = FirebaseMessaging.DefaultInstance;
            await messaging.SendAsync(message, cancellationToken);
            return true;
        }
        catch (FirebaseMessagingException ex) when (IsInvalidTokenError(ex))
        {
            await ClearVendorTokenAsync(vendorId, cancellationToken);
            return false;
        }
        catch (Exception ex)
        {
#pragma warning disable CA1848
            _logger.LogError(ex, "Failed to send FCM push to vendor {VendorId}", vendorId);
#pragma warning restore CA1848
            return false;
        }
    }

    private static bool IsInvalidTokenError(FirebaseMessagingException ex)
        => ex.MessagingErrorCode is MessagingErrorCode.Unregistered
            or MessagingErrorCode.SenderIdMismatch
            or MessagingErrorCode.InvalidArgument;

    private async Task ClearUserTokenAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is not null)
        {
            user.ClearFcmDeviceToken();
            await _context.SaveChangesAsync(cancellationToken);
        }
    }

    private async Task ClearVendorTokenAsync(Guid vendorId, CancellationToken cancellationToken)
    {
        var vendor = await _context.Vendors.FirstOrDefaultAsync(v => v.Id == vendorId, cancellationToken);
        if (vendor is not null)
        {
            vendor.ClearFcmDeviceToken();
            await _context.SaveChangesAsync(cancellationToken);
        }
    }
}

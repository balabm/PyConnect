namespace PondyConnect.Application.Features.FoodDelivery;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Application.Services;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

/// <summary>
/// Orchestrates the tri-state cancellation cascades for food delivery.
///
/// **Vendor Cancellation** (restaurant cancels — e.g. out of dough):
/// 1. Process an instant Razorpay refund to the Consumer.
/// 2. Send FCM push to Consumer: "Order cancelled by restaurant. Full refund initiated."
/// 3. Send FCM push/SignalR to assigned Captain: "Trip cancelled. Returning to pool."
/// 4. Set Captain status back to Online.
/// 5. Cancel the DispatchTask.
///
/// **Driver Abandonment** (captain drops after accepting, before pickup):
/// 1. Do NOT cancel the order — the customer's food is still being prepared.
/// 2. Emergency-release the DispatchTask (pushes it back to Available).
/// 3. Re-dispatch to the next nearest driver.
/// 4. Notify the Partner: "Assigning new Captain."
/// </summary>
public sealed class FoodCancellationService
{
    private readonly IApplicationDbContext _context;
    private readonly INotificationService _notifications;
    private readonly IPaymentRefundService _refundService;
    private readonly ILogger<FoodCancellationService> _logger;

    public FoodCancellationService(
        IApplicationDbContext context,
        INotificationService notifications,
        IPaymentRefundService refundService,
        ILogger<FoodCancellationService> logger)
    {
        _context = context;
        _notifications = notifications;
        _refundService = refundService;
        _logger = logger;
    }

    /// <summary>
    /// Vendor-initiated cancellation. The restaurant cancels the order
    /// (e.g. out of stock). Triggers instant refund + FCM to consumer +
    /// FCM to assigned driver + driver status reset.
    /// </summary>
    public async Task<VendorCancellationResult> CancelByVendorAsync(
        Guid orderId,
        Guid vendorId,
        string? reason,
        CancellationToken ct = default)
    {
        var order = await _context.FoodOrders
            .FirstOrDefaultAsync(o => o.Id == orderId, ct)
            ?? throw new InvalidOperationException("Order not found.");

        // Validate ownership: only the vendor who owns this order can cancel it.
        if (order.VendorId != vendorId)
            throw new UnauthorizedAccessException("Only the restaurant that owns this order can cancel it.");

        if (order.Status is FoodOrderStatus.Delivered)
            throw new InvalidOperationException("Cannot cancel a delivered order.");

        if (order.Status is FoodOrderStatus.Cancelled)
            throw new InvalidOperationException("Order is already cancelled.");

        var result = new VendorCancellationResult { OrderId = orderId, Reason = reason };

        // 1. Cancel the order.
        order.Cancel();

        // 2. Process instant Razorpay refund if payment was captured.
        if (order.PaymentStatus == PaymentStatus.Captured)
        {
            var payment = await _context.Payments
                .FirstOrDefaultAsync(p => p.FoodOrderId == orderId && p.Status == PaymentStatus.Captured, ct);

            if (payment is not null && !string.IsNullOrEmpty(payment.ProviderPaymentId))
            {
                var refundOk = await _refundService.RefundAsync(
                    payment.ProviderPaymentId,
                    order.TotalAmount,
                    $"Vendor cancellation: {reason ?? "out of stock"}",
                    ct);

                if (refundOk)
                {
                    payment.MarkRefunded();
                    result.RefundInitiated = true;
                    _logger.RefundSuccess(orderId, order.TotalAmount);
                }
                else
                {
                    result.RefundInitiated = false;
                    _logger.RefundFailed(orderId);
                }
            }
        }

        // 3. Cancel any assigned DispatchTask and release the driver.
        var task = await _context.DispatchTasks
            .FirstOrDefaultAsync(t => t.SourceEntityId == orderId && t.TaskType == DispatchTaskType.FoodDelivery, ct);

        if (task is not null && task.DriverId is { } driverId)
        {
            task.Cancel();
            result.DriverNotified = true;

            // Set driver back to Online (available for new dispatches).
            var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.Id == driverId, ct);
            if (driver is not null)
            {
                driver.GoOnline();
                _logger.DriverReleased(driverId);
            }

            // Send FCM to the driver: "Trip cancelled. Returning you to the pool."
            var driverUser = driver is not null
                ? await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == driver.UserId, ct)
                : null;

            if (driverUser is not null)
            {
                await _notifications.SendTargetedPushAsync(
                    driverUser.Id,
                    "Trip Cancelled",
                    "The restaurant cancelled this order. You've been returned to the available pool.",
                    dataPayload: new() { ["type"] = "food_cancelled", ["orderId"] = orderId.ToString() },
                    cancellationToken: ct);
            }
        }

        // 4. Send FCM to the consumer: "Order cancelled by restaurant. Full refund initiated."
        await _notifications.SendTargetedPushAsync(
            order.UserId,
            "Order Cancelled by Restaurant",
            result.RefundInitiated
                ? "Your order has been cancelled by the restaurant. A full refund of ₹" + order.TotalAmount.ToString("F0", System.Globalization.CultureInfo.InvariantCulture) + " has been initiated."
                : "Your order has been cancelled by the restaurant. Your refund is being processed.",
            dataPayload: new() { ["type"] = "order_cancelled", ["orderId"] = orderId.ToString() },
            cancellationToken: ct);

        result.ConsumerNotified = true;

        await _context.SaveChangesAsync(ct);
        _logger.VendorCancellationComplete(orderId, result.RefundInitiated, result.DriverNotified);

        return result;
    }

    /// <summary>
    /// Driver abandonment: the captain drops the order after accepting but
    /// before pickup. Does NOT cancel the order — the food is still being
    /// prepared. Emergency-releases the DispatchTask and re-dispatches to
    /// the next nearest driver. Notifies the partner.
    /// </summary>
    public async Task<DriverAbandonmentResult> HandleDriverAbandonmentAsync(
        Guid orderId,
        Guid driverId,
        string? reason,
        CancellationToken ct = default)
    {
        var order = await _context.FoodOrders
            .FirstOrDefaultAsync(o => o.Id == orderId, ct)
            ?? throw new InvalidOperationException("Order not found.");

        // Do NOT cancel the order. The food is still being prepared.
        // Only handle the dispatch task re-assignment.
        var task = await _context.DispatchTasks
            .FirstOrDefaultAsync(t => t.SourceEntityId == orderId && t.TaskType == DispatchTaskType.FoodDelivery, ct)
            ?? throw new InvalidOperationException("No dispatch task found for this order.");

        if (task.DriverId != driverId)
            throw new UnauthorizedAccessException("Only the assigned driver can abandon this task.");

        // Emergency-release the task (pushes it back to Available).
        task.EmergencyRelease();

        // Set the driver back to Online.
        var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.Id == driverId, ct);
        if (driver is not null)
        {
            driver.GoOnline();
        }

        await _context.SaveChangesAsync(ct);

        // Notify the partner: "Assigning new Captain."
        var vendor = await _context.Vendors
            .AsNoTracking()
            .FirstOrDefaultAsync(v => v.Id == order.VendorId, ct);

        if (vendor is not null)
        {
            await _notifications.SendPushToVendorAsync(
                vendor.Id,
                "Assigning New Captain",
                "The previous captain could not complete this delivery. We are assigning a new captain now.",
                dataPayload: new() { ["type"] = "driver_reassigned", ["orderId"] = orderId.ToString() },
                cancellationToken: ct);
        }

        _logger.DriverAbandonmentHandled(orderId, driverId);

        return new DriverAbandonmentResult
        {
            OrderId = orderId,
            TaskReDispatched = true,
            PartnerNotified = vendor is not null
        };
    }
}

public sealed class VendorCancellationResult
{
    public Guid OrderId { get; init; }
    public string? Reason { get; init; }
    public bool RefundInitiated { get; set; }
    public bool ConsumerNotified { get; set; }
    public bool DriverNotified { get; set; }
}

public sealed class DriverAbandonmentResult
{
    public Guid OrderId { get; init; }
    public bool TaskReDispatched { get; set; }
    public bool PartnerNotified { get; set; }
}

internal static partial class FoodCancellationLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Refund succeeded for order {OrderId}: {Amount}")]
    public static partial void RefundSuccess(this ILogger logger, Guid orderId, decimal amount);

    [LoggerMessage(Level = LogLevel.Error, Message = "Refund failed for order {OrderId}")]
    public static partial void RefundFailed(this ILogger logger, Guid orderId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Driver {DriverId} released back to online pool")]
    public static partial void DriverReleased(this ILogger logger, Guid driverId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Vendor cancellation complete for {OrderId}: refund={Refund}, driverNotified={DriverNotified}")]
    public static partial void VendorCancellationComplete(this ILogger logger, Guid orderId, bool refund, bool driverNotified);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Driver {DriverId} abandoned order {OrderId}. Re-dispatching.")]
    public static partial void DriverAbandonmentHandled(this ILogger logger, Guid orderId, Guid driverId);
}

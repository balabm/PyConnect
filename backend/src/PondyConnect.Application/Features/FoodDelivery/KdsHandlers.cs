namespace PondyConnect.Application.Features.FoodDelivery;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Application.Features.Wallet;
using PondyConnect.Domain.Enums;

// ── KDS Query ──

public sealed record GetKdsOrdersQuery : IRequest<IReadOnlyList<KdsOrderResponse>>;

public sealed record KdsOrderResponse(
    Guid Id,
    string OrderNumber,
    string CustomerName,
    string Stage,
    string VendorName,
    string? DeliveryAddress,
    string? Notes,
    DateTimeOffset PlacedAt,
    IReadOnlyList<KdsOrderItemResponse> Items);

public sealed record KdsOrderItemResponse(Guid Id, string Name, int Quantity, string? SpecialInstructions);

public sealed class GetKdsOrdersHandler : IRequestHandler<GetKdsOrdersQuery, IReadOnlyList<KdsOrderResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetKdsOrdersHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<KdsOrderResponse>> Handle(GetKdsOrdersQuery request, CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var vendorId = await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (vendorId == Guid.Empty)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var vendorName = await _context.Vendors.AsNoTracking()
            .Where(v => v.Id == vendorId)
            .Select(v => v.Name)
            .FirstOrDefaultAsync(cancellationToken) ?? "";

        // Fetch active orders (not delivered or cancelled) — sort on client side for SQLite compat
        var orders = await _context.FoodOrders
            .AsNoTracking()
            .Include(o => o.Items)
            .Where(o => o.VendorId == vendorId &&
                        o.Status != FoodOrderStatus.Delivered &&
                        o.Status != FoodOrderStatus.Cancelled)
            .ToListAsync(cancellationToken);

        // Resolve customer names
        var userIds = orders.Select(o => o.UserId).Distinct().ToList();
        var users = await _context.Users.AsNoTracking()
            .Where(u => userIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.Name, cancellationToken);

        return orders
            .OrderBy(o => o.PlacedAt)
            .Select(o => new KdsOrderResponse(
                Id: o.Id,
                OrderNumber: $"ORD-{o.Id.ToString().Substring(0, 8).ToUpperInvariant()}",
                CustomerName: users.GetValueOrDefault(o.UserId, "Guest"),
                Stage: MapStatusToKdsStage(o.Status),
                VendorName: vendorName,
                DeliveryAddress: o.DeliveryAddress,
                Notes: o.Notes,
                PlacedAt: o.PlacedAt,
                Items: o.Items.Select(i => new KdsOrderItemResponse(i.Id, i.Name, i.Quantity, i.SpecialInstructions)).ToList()))
            .ToList();
    }

    private static string MapStatusToKdsStage(FoodOrderStatus status) => status switch
    {
        FoodOrderStatus.Placed or FoodOrderStatus.Accepted => "incoming",
        FoodOrderStatus.Preparing => "preparing",
        FoodOrderStatus.OutForDelivery => "ready",
        FoodOrderStatus.Delivered => "completed",
        _ => "incoming"
    };
}

// ── KDS Advance Command ──

public sealed record AdvanceKdsOrderCommand(Guid OrderId) : IRequest<KdsOrderResponse>;

public sealed class AdvanceKdsOrderHandler : IRequestHandler<AdvanceKdsOrderCommand, KdsOrderResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IFoodDeliveryDispatchService? _foodDispatch;
    private readonly INotificationService? _notifications;
    private readonly WalletService? _walletService;

    public AdvanceKdsOrderHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
        _foodDispatch = null;
        _notifications = null;
        _walletService = null;
    }

    public AdvanceKdsOrderHandler(IApplicationDbContext context, ICurrentUserService currentUser, IFoodDeliveryDispatchService foodDispatch)
    {
        _context = context;
        _currentUser = currentUser;
        _foodDispatch = foodDispatch;
        _notifications = null;
        _walletService = null;
    }

    public AdvanceKdsOrderHandler(IApplicationDbContext context, ICurrentUserService currentUser, IFoodDeliveryDispatchService foodDispatch, INotificationService notifications)
    {
        _context = context;
        _currentUser = currentUser;
        _foodDispatch = foodDispatch;
        _notifications = notifications;
        _walletService = null;
    }

    public AdvanceKdsOrderHandler(IApplicationDbContext context, ICurrentUserService currentUser, IFoodDeliveryDispatchService foodDispatch, INotificationService notifications, WalletService walletService)
    {
        _context = context;
        _currentUser = currentUser;
        _foodDispatch = foodDispatch;
        _notifications = notifications;
        _walletService = walletService;
    }

    public async Task<KdsOrderResponse> Handle(AdvanceKdsOrderCommand request, CancellationToken cancellationToken)
    {
        var order = await _context.FoodOrders
            .Include(o => o.Items)
            .FirstOrDefaultAsync(o => o.Id == request.OrderId, cancellationToken)
            ?? throw new InvalidOperationException("Order not found.");

        var previousStatus = order.Status;

        // Track whether this advance transitions to OutForDelivery so we can
        // trigger driver dispatch after saving.
        var transitionsToOutForDelivery = false;

        // Advance through the KDS stage pipeline
        switch (order.Status)
        {
            case FoodOrderStatus.Placed:
                order.Accept();
                break;
            case FoodOrderStatus.Accepted:
                order.StartPreparing();
                break;
            case FoodOrderStatus.Preparing:
                order.Dispatch();
                transitionsToOutForDelivery = true;
                break;
            case FoodOrderStatus.OutForDelivery:
                order.Deliver();
                break;
            default:
                throw new InvalidOperationException("Order is already completed or cancelled.");
        }

        await _context.SaveChangesAsync(cancellationToken);

        // Dispatch to nearby drivers when the order transitions to OutForDelivery
        // via the KDS advance flow. This mirrors the UpdateOrderStatus endpoint.
        if (transitionsToOutForDelivery && _foodDispatch is not null)
        {
            await _foodDispatch.DispatchFoodOrderAsync(order.Id, cancellationToken);
        }

        // COD commission: when a cash order is delivered via the KDS advance
        // flow, debit the driver's cash-collection wallet for the 10% platform
        // commission and suspend if the hard limit is reached.
        if (_walletService is not null
            && order.Status == FoodOrderStatus.Delivered
            && order.PaymentMethod == PaymentMethod.Cash
            && order.TotalAmount > 0m)
        {
            var task = await _context.DispatchTasks.AsNoTracking()
                .FirstOrDefaultAsync(t => t.SourceEntityId == order.Id && t.DriverId.HasValue, cancellationToken);

            if (task?.DriverId is not null)
            {
                var commission = Math.Round(order.TotalAmount * 0.1m, 2, MidpointRounding.AwayFromZero);
                if (commission > 0m)
                {
                    await _walletService.RecordCommissionAsync(
                        task.DriverId.Value,
                        commission,
                        order.Id.ToString(),
                        $"COD commission for order {order.Id}",
                        cancellationToken);

                    await _walletService.CheckAndSuspendIfNeededAsync(task.DriverId.Value, cancellationToken);
                }
            }
        }

        // Fire-and-forget push to the consumer on key state transitions.
        if (_notifications is not null)
        {
            _ = SendFoodOrderStatusPushAsync(order, previousStatus, cancellationToken);
        }

        var vendorName = await _context.Vendors.AsNoTracking()
            .Where(v => v.Id == order.VendorId)
            .Select(v => v.Name)
            .FirstOrDefaultAsync(cancellationToken) ?? "";

        var customerName = await _context.Users.AsNoTracking()
            .Where(u => u.Id == order.UserId)
            .Select(u => u.Name)
            .FirstOrDefaultAsync(cancellationToken) ?? "Guest";

        return new KdsOrderResponse(
            Id: order.Id,
            OrderNumber: $"ORD-{order.Id.ToString().Substring(0, 8).ToUpperInvariant()}",
            CustomerName: customerName,
            Stage: order.Status switch
            {
                FoodOrderStatus.Placed or FoodOrderStatus.Accepted => "incoming",
                FoodOrderStatus.Preparing => "preparing",
                FoodOrderStatus.OutForDelivery => "ready",
                FoodOrderStatus.Delivered => "completed",
                _ => "incoming"
            },
            VendorName: vendorName,
            DeliveryAddress: order.DeliveryAddress,
            Notes: order.Notes,
            PlacedAt: order.PlacedAt,
            Items: order.Items.Select(i => new KdsOrderItemResponse(i.Id, i.Name, i.Quantity, i.SpecialInstructions)).ToList());
    }

    /// <summary>
    /// Best-effort FCM push to the consumer when a food order transitions to
    /// Preparing (ready) or OutForDelivery via the KDS advance flow.
    /// All exceptions are swallowed.
    /// </summary>
    private async Task SendFoodOrderStatusPushAsync(Domain.Entities.FoodOrder order, FoodOrderStatus previousStatus, CancellationToken cancellationToken)
    {
        try
        {
            var (title, body, route) = order.Status switch
            {
                FoodOrderStatus.Preparing =>
                    ("Your order is being prepared!",
                     $"The kitchen has started on your order #{order.Id.ToString().Substring(0, 8).ToUpperInvariant()}.",
                     $"/activity/food/{order.Id}"),
                FoodOrderStatus.OutForDelivery =>
                    ("Order out for delivery!",
                     $"Your order #{order.Id.ToString().Substring(0, 8).ToUpperInvariant()} is on the way.",
                     $"/activity/food/{order.Id}"),
                FoodOrderStatus.Delivered =>
                    ("Order delivered!",
                     $"Your order #{order.Id.ToString().Substring(0, 8).ToUpperInvariant()} has been delivered. Enjoy!",
                     $"/activity/food/{order.Id}"),
                _ => (null, null, null),
            };

            if (title is null)
                return;

            await _notifications!.SendTargetedPushAsync(
                order.UserId,
                title,
                body!,
                new Dictionary<string, string>
                {
                    { "click_action", "FLUTTER_NOTIFICATION_CLICK" },
                    { "route", route! },
                    { "type", "food_order_status" },
                    { "order_id", order.Id.ToString() },
                    { "status", order.Status.ToString() },
                },
                CancellationToken.None);
        }
        catch
        {
            // Best-effort delivery — never crash the KDS advance flow.
        }
    }
}

namespace PondyConnect.Application.Features.FoodDelivery;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
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

public sealed record KdsOrderItemResponse(string Name, int Quantity, string? SpecialInstructions);

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
                Items: o.Items.Select(i => new KdsOrderItemResponse(i.Name, i.Quantity, i.SpecialInstructions)).ToList()))
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

    public AdvanceKdsOrderHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
        _foodDispatch = null;
    }

    public AdvanceKdsOrderHandler(IApplicationDbContext context, ICurrentUserService currentUser, IFoodDeliveryDispatchService foodDispatch)
    {
        _context = context;
        _currentUser = currentUser;
        _foodDispatch = foodDispatch;
    }

    public async Task<KdsOrderResponse> Handle(AdvanceKdsOrderCommand request, CancellationToken cancellationToken)
    {
        var order = await _context.FoodOrders
            .Include(o => o.Items)
            .FirstOrDefaultAsync(o => o.Id == request.OrderId, cancellationToken)
            ?? throw new InvalidOperationException("Order not found.");

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
            Items: order.Items.Select(i => new KdsOrderItemResponse(i.Name, i.Quantity, i.SpecialInstructions)).ToList());
    }
}

namespace PondyConnect.Application.Features.FoodDelivery;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

public sealed record GetFoodOrderQuery(Guid OrderId) : IRequest<FoodOrderDetailResponse>;

public sealed record FoodOrderDetailResponse(
    Guid Id,
    Guid VendorId,
    string VendorName,
    string Status,
    decimal VendorPayout,
    decimal SubTotal,
    decimal DeliveryFee,
    decimal LateNightDriverBonus,
    decimal PlatformFee,
    decimal TotalAmount,
    string DeliveryAddress,
    string PaymentMethod,
    DateTimeOffset PlacedAt,
    DateTimeOffset? DeliveredAt,
    IReadOnlyList<FoodOrderItemResponse> Items);

public sealed record FoodOrderItemResponse(string Name, int Quantity, decimal UnitPrice, decimal LineTotal, string? SpecialInstructions);

public sealed class GetFoodOrderHandler : IRequestHandler<GetFoodOrderQuery, FoodOrderDetailResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetFoodOrderHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<FoodOrderDetailResponse> Handle(GetFoodOrderQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var order = await _context.FoodOrders
            .AsNoTracking()
            .Include(o => o.Items)
            .FirstOrDefaultAsync(o => o.Id == request.OrderId, cancellationToken)
            ?? throw new InvalidOperationException("Order not found.");

        // Ownership check: only the order owner, the assigned vendor, or an admin may view details.
        var isOwner = order.UserId == userId;
        var isAdmin = string.Equals(_currentUser.Role, "Admin", StringComparison.OrdinalIgnoreCase);
        var isVendor = false;
        if (!isOwner && !isAdmin)
        {
            var vendorEntity = await _context.Vendors.AsNoTracking().FirstOrDefaultAsync(v => v.Id == order.VendorId, cancellationToken);
            isVendor = vendorEntity != null && vendorEntity.ContactPhone == _currentUser.Phone;
        }
        if (!isOwner && !isAdmin && !isVendor)
            throw new UnauthorizedAccessException("You are not authorized to view this order.");

        var vendor = await _context.Vendors.AsNoTracking().FirstOrDefaultAsync(v => v.Id == order.VendorId, cancellationToken);

        return new FoodOrderDetailResponse(
            Id: order.Id,
            VendorId: order.VendorId,
            VendorName: vendor?.Name ?? "Unknown",
            Status: order.Status.ToString(),
            VendorPayout: order.VendorPayout,
            SubTotal: order.SubTotal,
            DeliveryFee: order.DeliveryFee,
            LateNightDriverBonus: order.LateNightDriverBonus,
            PlatformFee: order.PlatformFee,
            TotalAmount: order.TotalAmount,
            DeliveryAddress: order.DeliveryAddress,
            PaymentMethod: order.PaymentMethod.ToString(),
            PlacedAt: order.PlacedAt,
            DeliveredAt: order.DeliveredAt,
            Items: order.Items.Select(i => new FoodOrderItemResponse(i.Name, i.Quantity, i.UnitPrice, i.LineTotal, i.SpecialInstructions)).ToList());
    }
}

public sealed record ListUserFoodOrdersQuery(int Page = 1, int PageSize = 20) : IRequest<IReadOnlyList<FoodOrderSummaryResponse>>;

public sealed record FoodOrderSummaryResponse(
    Guid Id,
    string VendorName,
    string Status,
    decimal TotalAmount,
    DateTimeOffset PlacedAt);

public sealed class ListUserFoodOrdersHandler : IRequestHandler<ListUserFoodOrdersQuery, IReadOnlyList<FoodOrderSummaryResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListUserFoodOrdersHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<FoodOrderSummaryResponse>> Handle(ListUserFoodOrdersQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var orders = await _context.FoodOrders.AsNoTracking()
            .Where(o => o.UserId == userId)
            .ToListAsync(cancellationToken);

        var vendorIds = orders.Select(o => o.VendorId).Distinct().ToList();
        var vendors = await _context.Vendors.AsNoTracking()
            .Where(v => vendorIds.Contains(v.Id))
            .ToDictionaryAsync(v => v.Id, v => v.Name, cancellationToken);

        return orders
            .OrderByDescending(o => o.PlacedAt)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(o => new FoodOrderSummaryResponse(o.Id, vendors.GetValueOrDefault(o.VendorId, "Unknown"), o.Status.ToString(), o.TotalAmount, o.PlacedAt))
            .ToList();
    }
}

public sealed record ListVendorFoodOrdersQuery(int Page = 1, int PageSize = 20) : IRequest<IReadOnlyList<FoodOrderSummaryResponse>>;

public sealed class ListVendorFoodOrdersHandler : IRequestHandler<ListVendorFoodOrdersQuery, IReadOnlyList<FoodOrderSummaryResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListVendorFoodOrdersHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<FoodOrderSummaryResponse>> Handle(ListVendorFoodOrdersQuery request, CancellationToken cancellationToken)
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

        var orders = await _context.FoodOrders.AsNoTracking()
            .Where(o => o.VendorId == vendorId)
            .ToListAsync(cancellationToken);

        return orders
            .OrderByDescending(o => o.PlacedAt)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(o => new FoodOrderSummaryResponse(o.Id, "", o.Status.ToString(), o.TotalAmount, o.PlacedAt))
            .ToList();
    }
}

public sealed record UpdateFoodOrderStatusCommand(Guid OrderId, string NewStatus) : IRequest<Unit>;

public sealed class UpdateFoodOrderStatusHandler : IRequestHandler<UpdateFoodOrderStatusCommand, Unit>
{
    private readonly IApplicationDbContext _context;

    public UpdateFoodOrderStatusHandler(IApplicationDbContext context) => _context = context;

    public async Task<Unit> Handle(UpdateFoodOrderStatusCommand request, CancellationToken cancellationToken)
    {
        var order = await _context.FoodOrders.FirstOrDefaultAsync(o => o.Id == request.OrderId, cancellationToken)
            ?? throw new InvalidOperationException("Order not found.");

        switch (request.NewStatus.ToLowerInvariant())
        {
            case "accepted": order.Accept(); break;
            case "preparing": order.StartPreparing(); break;
            case "outfordelivery": order.Dispatch(); break;
            case "delivered": order.Deliver(); break;
            case "cancelled": order.Cancel(); break;
            default: throw new ArgumentException($"Unknown status: {request.NewStatus}");
        }

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed record CancelFoodOrderCommand(Guid OrderId, string? Reason = null) : IRequest<Unit>;

public sealed class CancelFoodOrderHandler : IRequestHandler<CancelFoodOrderCommand, Unit>
{
    private readonly IApplicationDbContext _context;

    public CancelFoodOrderHandler(IApplicationDbContext context) => _context = context;

    public async Task<Unit> Handle(CancelFoodOrderCommand request, CancellationToken cancellationToken)
    {
        var order = await _context.FoodOrders.FirstOrDefaultAsync(o => o.Id == request.OrderId, cancellationToken)
            ?? throw new InvalidOperationException("Order not found.");

        if (order.Status is FoodOrderStatus.Delivered)
            throw new InvalidOperationException("Cannot cancel a delivered order.");

        order.Cancel();
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

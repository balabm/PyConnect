namespace PondyConnect.Application.Features.FoodDelivery;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;
using PondyConnect.Application.Features.GeoFence;

public sealed record CreateFoodOrderCommand(
    Guid VendorId,
    string DeliveryAddress,
    double DeliveryLatitude,
    double DeliveryLongitude,
    PaymentMethod PaymentMethod,
    Guid? VenueId = null,
    string? Notes = null,
    IReadOnlyList<CreateFoodOrderItemRequest>? Items = null) : IRequest<CheckoutResponse>;

public sealed record CreateFoodOrderItemRequest(string Name, int Quantity, decimal UnitPrice, string? SpecialInstructions = null);

public sealed record CheckoutResponse(
    Guid OrderId,
    decimal VendorPayout,
    decimal SubTotal,
    decimal DeliveryFee,
    decimal LateNightDriverBonus,
    decimal PlatformFee,
    decimal TotalAmount,
    string Status);

public sealed class CreateFoodOrderValidator : AbstractValidator<CreateFoodOrderCommand>
{
    public CreateFoodOrderValidator()
    {
        RuleFor(x => x.VendorId).NotEmpty();
        RuleFor(x => x.DeliveryAddress).NotEmpty().MaximumLength(500);
        RuleFor(x => x.DeliveryLatitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.DeliveryLongitude).InclusiveBetween(-180, 180);
        RuleFor(x => x.Items).NotEmpty().Must(items => items!.All(i => i.Quantity > 0 && i.UnitPrice > 0));
    }
}

public sealed class CreateFoodOrderHandler : IRequestHandler<CreateFoodOrderCommand, CheckoutResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly ServiceAreaValidator _serviceArea;

    public CreateFoodOrderHandler(IApplicationDbContext context, ICurrentUserService currentUser, ServiceAreaValidator serviceArea)
    {
        _context = context;
        _currentUser = currentUser;
        _serviceArea = serviceArea;
    }

    public async Task<CheckoutResponse> Handle(CreateFoodOrderCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var vendor = await _context.Vendors.FirstOrDefaultAsync(v => v.Id == request.VendorId && v.IsActive, cancellationToken)
            ?? throw new InvalidOperationException("Vendor not found or inactive.");

        var deliveryLocation = GeoLocation.Create(request.DeliveryLatitude, request.DeliveryLongitude);
        _serviceArea.EnsureWithinZone(deliveryLocation);

        // Validate that ordered items exist in the vendor's menu and match the recorded price
        if (request.Items != null && request.Items.Count > 0)
        {
            var menuItemIds = await _context.MenuItems.AsNoTracking()
                .Where(m => m.VendorId == request.VendorId)
                .ToDictionaryAsync(m => m.Id, m => m, cancellationToken);

            foreach (var item in request.Items)
            {
                // If the item name doesn't match any menu item for this vendor, reject
                var matchingItem = menuItemIds.Values.FirstOrDefault(m =>
                    string.Equals(m.Name, item.Name, StringComparison.OrdinalIgnoreCase));

                if (matchingItem is null)
                    throw new InvalidOperationException($"Item '{item.Name}' is not available on this vendor's menu.");

                if (!matchingItem.IsAvailable)
                    throw new InvalidOperationException($"Item '{item.Name}' is currently out of stock.");

                if (matchingItem.Price != item.UnitPrice)
                    throw new InvalidOperationException($"Price mismatch for item '{item.Name}'. Expected {matchingItem.Price}, got {item.UnitPrice}.");
            }
        }

        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        var isProMember = user?.IsProMember ?? false;

        var subTotal = request.Items?.Sum(i => i.Quantity * i.UnitPrice) ?? 0m;
        var pricing = OrderPricingService.CalculatePricing(subTotal, isProMember, DateTimeOffset.UtcNow);

        var order = FoodOrder.Create(
            userId: userId,
            vendorId: request.VendorId,
            deliveryAddress: request.DeliveryAddress,
            deliveryLocation: deliveryLocation,
            subTotal: pricing.SubTotal,
            deliveryFee: pricing.DeliveryFee,
            lateNightDriverBonus: pricing.LateNightDriverBonus,
            paymentMethod: request.PaymentMethod,
            venueId: request.VenueId,
            notes: request.Notes);

        if (request.Items != null)
        {
            foreach (var item in request.Items)
                order.AddItem(item.Name, item.Quantity, item.UnitPrice, item.SpecialInstructions);
        }

        _context.FoodOrders.Add(order);
        await _context.SaveChangesAsync(cancellationToken);

        return new CheckoutResponse(
            OrderId: order.Id,
            VendorPayout: order.VendorPayout,
            SubTotal: order.SubTotal,
            DeliveryFee: order.DeliveryFee,
            LateNightDriverBonus: order.LateNightDriverBonus,
            PlatformFee: order.PlatformFee,
            TotalAmount: order.TotalAmount,
            Status: order.Status.ToString());
    }
}

namespace PondyConnect.Application.Features.FoodDelivery;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Fraud;
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

public sealed record CreateFoodOrderItemRequest(
    string Name,
    int Quantity,
    decimal UnitPrice,
    string? SpecialInstructions = null,
    IReadOnlyList<Guid>? SelectedModifierIds = null);

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
    private readonly IFraudDetectionService _fraudDetection;

    public CreateFoodOrderHandler(IApplicationDbContext context, ICurrentUserService currentUser, ServiceAreaValidator serviceArea, IFraudDetectionService fraudDetection)
    {
        _context = context;
        _currentUser = currentUser;
        _serviceArea = serviceArea;
        _fraudDetection = fraudDetection;
    }

    public async Task<CheckoutResponse> Handle(CreateFoodOrderCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        // COD enforcement: consumers flagged with CodRestricted cannot pay cash.
        if (request.PaymentMethod == PaymentMethod.Cash
            && await _fraudDetection.IsCodRestrictedAsync(userId.ToString()))
        {
            throw new CodRestrictedException();
        }

        var vendor = await _context.Vendors.FirstOrDefaultAsync(v => v.Id == request.VendorId && v.IsActive, cancellationToken)
            ?? throw new InvalidOperationException("Vendor not found or inactive.");

        var deliveryLocation = GeoLocation.Create(request.DeliveryLatitude, request.DeliveryLongitude);
        _serviceArea.EnsureWithinZone(deliveryLocation);

        // Validate that ordered items exist in the vendor's menu, match the
        // recorded price, and satisfy all modifier group constraints.
        if (request.Items != null && request.Items.Count > 0)
        {
            var menuItems = await _context.MenuItems.AsNoTracking()
                .Where(m => m.VendorId == request.VendorId)
                .Include(m => m.ModifierGroups.OrderBy(g => g.SortOrder))
                    .ThenInclude(g => g.Modifiers)
                .ToListAsync(cancellationToken);

            var menuItemByExactName = menuItems.ToDictionary(
                m => m.Name, m => m, StringComparer.OrdinalIgnoreCase);

            foreach (var item in request.Items)
            {
                if (!menuItemByExactName.TryGetValue(item.Name, out var matchingItem))
                    throw new InvalidOperationException($"Item '{item.Name}' is not available on this vendor's menu.");

                if (!matchingItem.IsAvailable)
                    throw new InvalidOperationException($"Item '{item.Name}' is currently out of stock.");

                // Validate modifier selections and compute the expected unit price.
                var expectedUnitPrice = matchingItem.Price;
                var selectedModifierIds = (item.SelectedModifierIds ?? []).ToList();

                if (selectedModifierIds.Count > 0)
                {
                    // Build a lookup of all available modifiers for this menu item.
                    var allModifiers = matchingItem.ModifierGroups
                        .SelectMany(g => g.Modifiers)
                        .ToDictionary(m => m.Id);

                    // Verify every selected modifier exists and belongs to this item.
                    foreach (var modId in selectedModifierIds)
                    {
                        if (!allModifiers.TryGetValue(modId, out var modifier))
                            throw new InvalidOperationException($"Selected modifier '{modId}' does not belong to item '{item.Name}'.");

                        if (!modifier.IsAvailable)
                            throw new InvalidOperationException($"Modifier '{modifier.Name}' is not available.");
                    }

                    // Validate per-group min/max selection constraints.
                    foreach (var group in matchingItem.ModifierGroups)
                    {
                        var selectedInGroup = selectedModifierIds
                            .Where(id => group.Modifiers.Any(m => m.Id == id))
                            .ToList();

                        if (group.MinSelections > 0 && selectedInGroup.Count < group.MinSelections)
                            throw new InvalidOperationException(
                                $"Modifier group '{group.Name}' requires at least {group.MinSelections} selection(s) for item '{item.Name}'.");

                        if (group.MaxSelections > 0 && selectedInGroup.Count > group.MaxSelections)
                            throw new InvalidOperationException(
                                $"Modifier group '{group.Name}' allows at most {group.MaxSelections} selection(s) for item '{item.Name}'.");
                    }

                    // Add modifier prices to the expected unit price.
                    expectedUnitPrice += selectedModifierIds
                        .Sum(id => allModifiers[id].Price);
                }

                if (matchingItem.Price != item.UnitPrice && expectedUnitPrice != item.UnitPrice)
                    throw new InvalidOperationException(
                        $"Price mismatch for item '{item.Name}'. Expected {expectedUnitPrice}, got {item.UnitPrice}.");
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

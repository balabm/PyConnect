namespace PondyConnect.Application.Features.FoodDelivery;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Fraud;
using PondyConnect.Application.Services;
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
    IReadOnlyList<CreateFoodOrderItemRequest>? Items = null,
    string? RazorpayOrderId = null,
    string? RazorpayPaymentId = null,
    string? RazorpaySignature = null,
    int? TableId = null,
    Guid? DineInSessionId = null) : IRequest<CheckoutResponse>;

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
    decimal Taxes,
    decimal PlatformFee,
    decimal TotalAmount,
    string Status);

public sealed class CreateFoodOrderValidator : AbstractValidator<CreateFoodOrderCommand>
{
    public CreateFoodOrderValidator()
    {
        RuleFor(x => x.VendorId).NotEmpty();
        RuleFor(x => x.Items).NotEmpty().Must(items => items!.All(i => i.Quantity > 0 && i.UnitPrice > 0));

        // Dine-in orders bypass delivery address/location validation
        When(x => !x.TableId.HasValue, () =>
        {
            RuleFor(x => x.DeliveryAddress).NotEmpty().MaximumLength(500);
            RuleFor(x => x.DeliveryLatitude).InclusiveBetween(-90, 90);
            RuleFor(x => x.DeliveryLongitude).InclusiveBetween(-180, 180);
        });

        When(x => x.TableId.HasValue, () =>
        {
            RuleFor(x => x.TableId).GreaterThan(0);
        });
    }
}

public sealed class CreateFoodOrderHandler : IRequestHandler<CreateFoodOrderCommand, CheckoutResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly ServiceAreaValidator _serviceArea;
    private readonly IFraudDetectionService _fraudDetection;
    private readonly IPaymentGateway _gateway;
    private readonly IPaymentRefundService _refundService;
    private readonly ILogger<CreateFoodOrderHandler> _logger;

    public CreateFoodOrderHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        ServiceAreaValidator serviceArea,
        IFraudDetectionService fraudDetection,
        IPaymentGateway gateway,
        IPaymentRefundService refundService,
        ILogger<CreateFoodOrderHandler> logger)
    {
        _context = context;
        _currentUser = currentUser;
        _serviceArea = serviceArea;
        _fraudDetection = fraudDetection;
        _gateway = gateway;
        _refundService = refundService;
        _logger = logger;
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

        // Service area validation only applies to delivery orders, not dine-in
        if (!request.TableId.HasValue)
        {
            var deliveryLocation = GeoLocation.Create(request.DeliveryLatitude, request.DeliveryLongitude);
            _serviceArea.EnsureWithinZone(deliveryLocation);
        }

        // Look up the user early so we can compute live pricing for conflict
        // responses and the final order in a single pass.
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        var isProMember = user?.IsProMember ?? false;

        // Validate that ordered items exist in the vendor's menu, match the
        // recorded price, and satisfy all modifier group constraints.
        // If any price has changed since the client built the cart, throw a
        // CartPriceConflictException (HTTP 409) with the live prices so the
        // client can update the cart and prompt the user to review.
        if (request.Items != null && request.Items.Count > 0)
        {
            var menuItems = await _context.MenuItems.AsNoTracking()
                .Where(m => m.VendorId == request.VendorId)
                .Include(m => m.ModifierGroups.OrderBy(g => g.SortOrder))
                    .ThenInclude(g => g.Modifiers)
                .ToListAsync(cancellationToken);

            var menuItemByExactName = menuItems.ToDictionary(
                m => m.Name, m => m, StringComparer.OrdinalIgnoreCase);

            // Collect live prices for all items in the request (for 409 response).
            var liveItemPrices = new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase);
            var hasPriceConflict = false;

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

                // Record the live price for this item (including modifiers).
                liveItemPrices[item.Name] = expectedUnitPrice;

                if (expectedUnitPrice != item.UnitPrice)
                    hasPriceConflict = true;
            }

            // If any price has changed, return a 409 Conflict with the live
            // prices and recalculated totals so the client can update the cart.
            if (hasPriceConflict)
            {
                var liveSubTotal = request.Items.Sum(i => i.Quantity * liveItemPrices[i.Name]);
                var livePricing = OrderPricingService.CalculatePricing(liveSubTotal, isProMember, DateTimeOffset.UtcNow);
                throw new CartPriceConflictException(liveItemPrices, liveSubTotal, livePricing.TotalAmount);
            }
        }

        var subTotal = request.Items?.Sum(i => i.Quantity * i.UnitPrice) ?? 0m;
        var pricing = OrderPricingService.CalculatePricing(subTotal, isProMember, DateTimeOffset.UtcNow);

        FoodOrder order;

        // Dine-in orders bypass delivery address, delivery fee, and captain dispatch.
        // They route directly to the KDS tablet.
        if (request.TableId.HasValue)
        {
            // Dine-in: no delivery fee, no late-night bonus, no dispatch
            var dineInTaxes = subTotal * OrderPricingService.GstRate;
            order = FoodOrder.CreateDineIn(
                userId: userId,
                vendorId: request.VendorId,
                tableId: request.TableId.Value,
                subTotal: subTotal,
                taxes: dineInTaxes,
                paymentMethod: request.PaymentMethod,
                venueId: request.VenueId,
                notes: request.Notes);

            _logger.LogInformation(
                "Dine-in order created for table {TableId} at vendor {VendorId}, bypassing dispatch",
                request.TableId.Value, request.VendorId);
        }
        else
        {
            var deliveryLocation = GeoLocation.Create(request.DeliveryLatitude, request.DeliveryLongitude);
            _serviceArea.EnsureWithinZone(deliveryLocation);

            order = FoodOrder.Create(
                userId: userId,
                vendorId: request.VendorId,
                deliveryAddress: request.DeliveryAddress,
                deliveryLocation: deliveryLocation,
                subTotal: pricing.SubTotal,
                deliveryFee: pricing.DeliveryFee,
                lateNightDriverBonus: pricing.LateNightDriverBonus,
                taxes: pricing.Taxes,
                paymentMethod: request.PaymentMethod,
                venueId: request.VenueId,
                notes: request.Notes);
        }

        if (request.Items != null)
        {
            foreach (var item in request.Items)
                order.AddItem(item.Name, item.Quantity, item.UnitPrice, item.SpecialInstructions);
        }

        // Wrap the "payment verified -> persist order" step in an explicit
        // transaction. If the database fails to commit after Razorpay has
        // captured the money, we refund the consumer automatically.
        await using var transaction = await _context.BeginTransactionAsync(cancellationToken);

        string? paymentId = null;
        var verifiedAmount = order.TotalAmount;

        try
        {
            // Online payments must have a valid Razorpay client-side signature.
            if (request.PaymentMethod != PaymentMethod.Cash)
            {
                if (string.IsNullOrWhiteSpace(request.RazorpayOrderId)
                    || string.IsNullOrWhiteSpace(request.RazorpayPaymentId)
                    || string.IsNullOrWhiteSpace(request.RazorpaySignature))
                {
                    throw new InvalidOperationException("Razorpay payment details are required for online payment.");
                }

                var signatureValid = await _gateway.VerifyPaymentSignatureAsync(
                    request.RazorpayOrderId,
                    request.RazorpayPaymentId,
                    request.RazorpaySignature,
                    cancellationToken);

                if (!signatureValid)
                    throw new InvalidOperationException("Payment signature verification failed.");

                paymentId = request.RazorpayPaymentId;
                order.RecordPayment(PaymentStatus.Captured);
            }

            _context.FoodOrders.Add(order);
            await _context.SaveChangesAsync(cancellationToken);

            if (transaction is not null)
                await transaction.CommitAsync(cancellationToken);

            return new CheckoutResponse(
                OrderId: order.Id,
                VendorPayout: order.VendorPayout,
                SubTotal: order.SubTotal,
                DeliveryFee: order.DeliveryFee,
                LateNightDriverBonus: order.LateNightDriverBonus,
                Taxes: order.Taxes,
                PlatformFee: order.PlatformFee,
                TotalAmount: order.TotalAmount,
                Status: order.Status.ToString());
        }
        catch (Exception ex)
        {
            if (transaction is not null)
                await transaction.RollbackAsync(cancellationToken);

            if (!string.IsNullOrEmpty(paymentId))
            {
                _logger.LogCritical(
                    ex,
                    "CRITICAL_AUTO_REFUND: Food order creation failed after payment {PaymentId}. Initiating refund.",
                    paymentId);
                _ = await _refundService.RefundAsync(
                    paymentId,
                    verifiedAmount,
                    "Food order creation failed after payment",
                    cancellationToken);
            }
            else
            {
                _logger.LogCritical(
                    ex,
                    "CRITICAL_AUTO_REFUND: Food order creation failed before payment could be verified.");
            }

            throw;
        }
    }
}

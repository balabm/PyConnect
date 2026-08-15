namespace PondyConnect.Application.Features.QuickCommerce;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;
using PondyConnect.Application.Features.GeoFence;

public sealed record CreateProductCommand(
    string Name,
    decimal Price,
    ProductCategory Category,
    string SubCategory,
    int StockCount = 0,
    Guid? VendorId = null,
    string? Description = null,
    string? Brand = null,
    string? ImageUrl = null,
    bool IsLateNightEssential = false) : IRequest<ProductResponse>;

public sealed record ProductResponse(
    Guid Id,
    Guid? VendorId,
    string Name,
    string? Description,
    decimal Price,
    string Category,
    string SubCategory,
    string? Brand,
    bool IsAvailable,
    int StockCount,
    bool IsLateNightEssential,
    string? ImageUrl);

public sealed class CreateProductValidator : AbstractValidator<CreateProductCommand>
{
    public CreateProductValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Price).GreaterThan(0);
        RuleFor(x => x.SubCategory).NotEmpty().MaximumLength(50);
        RuleFor(x => x.StockCount).GreaterThanOrEqualTo(0);
    }
}

public sealed class CreateProductHandler : IRequestHandler<CreateProductCommand, ProductResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateProductHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<ProductResponse> Handle(CreateProductCommand request, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone
            ?? throw new UnauthorizedAccessException("Authenticated phone not found.");

        var vendor = await _context.Vendors
            .AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == phone && v.IsApproved, cancellationToken)
            ?? throw new UnauthorizedAccessException("No approved vendor found for the authenticated user.");

        var product = Product.Create(
            name: request.Name,
            price: request.Price,
            category: request.Category,
            subCategory: request.SubCategory,
            stockCount: request.StockCount,
            vendorId: vendor.Id,
            description: request.Description,
            brand: request.Brand,
            imageUrl: request.ImageUrl,
            isLateNightEssential: request.IsLateNightEssential);

        _context.Products.Add(product);
        await _context.SaveChangesAsync(cancellationToken);

        return MapToResponse(product);
    }

    private static ProductResponse MapToResponse(Product p) => new(
        p.Id, p.VendorId, p.Name, p.Description, p.Price,
        p.Category.ToString(), p.SubCategory, p.Brand, p.IsAvailable, p.StockCount, p.IsLateNightEssential, p.ImageUrl);
}

public sealed record ListProductsQuery(
    ProductCategory? Category = null,
    bool? IsLateNightEssential = null,
    bool OnlyAvailable = true) : IRequest<IReadOnlyList<ProductResponse>>;

public sealed class ListProductsHandler : IRequestHandler<ListProductsQuery, IReadOnlyList<ProductResponse>>
{
    private readonly IApplicationDbContext _context;

    public ListProductsHandler(IApplicationDbContext context) => _context = context;

    public async Task<IReadOnlyList<ProductResponse>> Handle(ListProductsQuery request, CancellationToken cancellationToken)
    {
        var query = _context.Products.AsNoTracking();
        if (request.OnlyAvailable)
            query = query.Where(p => p.IsAvailable);
        if (request.Category.HasValue)
            query = query.Where(p => p.Category == request.Category.Value);
        if (request.IsLateNightEssential.HasValue)
            query = query.Where(p => p.IsLateNightEssential == request.IsLateNightEssential.Value);

        var products = await query.OrderBy(p => p.Category).ThenBy(p => p.Name).ToListAsync(cancellationToken);
        return products.Select(p => new ProductResponse(p.Id, p.VendorId, p.Name, p.Description, p.Price, p.Category.ToString(), p.SubCategory, p.Brand, p.IsAvailable, p.StockCount, p.IsLateNightEssential, p.ImageUrl)).ToList();
    }
}

public sealed record GetProductQuery(Guid ProductId) : IRequest<ProductResponse>;

public sealed class GetProductHandler : IRequestHandler<GetProductQuery, ProductResponse>
{
    private readonly IApplicationDbContext _context;

    public GetProductHandler(IApplicationDbContext context) => _context = context;

    public async Task<ProductResponse> Handle(GetProductQuery request, CancellationToken cancellationToken)
    {
        var product = await _context.Products.AsNoTracking().FirstOrDefaultAsync(p => p.Id == request.ProductId, cancellationToken)
            ?? throw new InvalidOperationException("Product not found.");
        return new ProductResponse(product.Id, product.VendorId, product.Name, product.Description, product.Price, product.Category.ToString(), product.SubCategory, product.Brand, product.IsAvailable, product.StockCount, product.IsLateNightEssential, product.ImageUrl);
    }
}

public sealed record CreateProductOrderCommand(
    string DeliveryAddress,
    double DeliveryLatitude,
    double DeliveryLongitude,
    Guid? VendorId = null,
    IReadOnlyList<CreateProductOrderItemRequest>? Items = null) : IRequest<ProductOrderResponse>;

public sealed record CreateProductOrderItemRequest(Guid ProductId, int Quantity);

public sealed record ProductOrderResponse(
    Guid OrderId,
    decimal SubTotal,
    decimal DeliveryFee,
    decimal TotalAmount,
    string Status);

public sealed class CreateProductOrderValidator : AbstractValidator<CreateProductOrderCommand>
{
    public CreateProductOrderValidator()
    {
        RuleFor(x => x.DeliveryAddress).NotEmpty().MaximumLength(500);
        RuleFor(x => x.DeliveryLatitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.DeliveryLongitude).InclusiveBetween(-180, 180);
        RuleFor(x => x.Items).NotEmpty();
    }
}

public sealed class CreateProductOrderHandler : IRequestHandler<CreateProductOrderCommand, ProductOrderResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly ServiceAreaValidator _serviceArea;

    public CreateProductOrderHandler(IApplicationDbContext context, ICurrentUserService currentUser, ServiceAreaValidator serviceArea)
    {
        _context = context;
        _currentUser = currentUser;
        _serviceArea = serviceArea;
    }

    public async Task<ProductOrderResponse> Handle(CreateProductOrderCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var deliveryLocation = GeoLocation.Create(request.DeliveryLatitude, request.DeliveryLongitude);
        _serviceArea.EnsureWithinZone(deliveryLocation);

        const decimal deliveryFee = 40m;
        var order = ProductOrder.Create(userId, request.DeliveryAddress, deliveryLocation, deliveryFee, request.VendorId);

        if (request.Items != null)
        {
            foreach (var item in request.Items)
            {
                if (item.Quantity <= 0)
                    throw new InvalidOperationException("Quantity must be greater than 0.");

                var product = await _context.Products.FirstOrDefaultAsync(p => p.Id == item.ProductId && p.IsAvailable, cancellationToken)
                    ?? throw new InvalidOperationException($"Product {item.ProductId} not found or unavailable.");

                if (product.StockCount < item.Quantity)
                    throw new InvalidOperationException($"Insufficient stock for '{product.Name}'. Available: {product.StockCount}, requested: {item.Quantity}.");

                order.AddItem(product.Name, item.Quantity, product.Price);
            }
        }

        _context.ProductOrders.Add(order);
        await _context.SaveChangesAsync(cancellationToken);

        return new ProductOrderResponse(order.Id, order.SubTotal, order.DeliveryFee, order.TotalAmount, order.Status.ToString());
    }
}

public sealed record GetBundleSuggestionsQuery(IReadOnlyList<Guid> ProductIds) : IRequest<IReadOnlyList<ProductResponse>>;

public sealed class GetBundleSuggestionsHandler : IRequestHandler<GetBundleSuggestionsQuery, IReadOnlyList<ProductResponse>>
{
    private readonly IApplicationDbContext _context;

    public GetBundleSuggestionsHandler(IApplicationDbContext context) => _context = context;

    public async Task<IReadOnlyList<ProductResponse>> Handle(GetBundleSuggestionsQuery request, CancellationToken cancellationToken)
    {
        var cartProducts = await _context.Products.AsNoTracking()
            .Where(p => request.ProductIds.Contains(p.Id))
            .ToListAsync(cancellationToken);

        var cartCategories = cartProducts.Select(p => p.Category).Distinct().ToList();
        var suggestedCategories = ProductCartService.GetSuggestedCategories(cartCategories).ToList();

        if (suggestedCategories.Count == 0)
            return [];

        var suggestions = await _context.Products.AsNoTracking()
            .Where(p => p.IsAvailable && suggestedCategories.Contains(p.Category) && !request.ProductIds.Contains(p.Id))
            .Take(5)
            .ToListAsync(cancellationToken);

        return suggestions.Select(p => new ProductResponse(p.Id, p.VendorId, p.Name, p.Description, p.Price, p.Category.ToString(), p.SubCategory, p.Brand, p.IsAvailable, p.StockCount, p.IsLateNightEssential, p.ImageUrl)).ToList();
    }
}

public sealed record ListUserProductOrdersQuery(int Page = 1, int PageSize = 20) : IRequest<IReadOnlyList<ProductOrderSummaryResponse>>;

public sealed record ProductOrderSummaryResponse(Guid Id, string Status, decimal TotalAmount, DateTimeOffset PlacedAt);

public sealed class ListUserProductOrdersHandler : IRequestHandler<ListUserProductOrdersQuery, IReadOnlyList<ProductOrderSummaryResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListUserProductOrdersHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<ProductOrderSummaryResponse>> Handle(ListUserProductOrdersQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var orders = await _context.ProductOrders.AsNoTracking()
            .Where(o => o.UserId == userId)
            .ToListAsync(cancellationToken);

        return orders
            .OrderByDescending(o => o.PlacedAt)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(o => new ProductOrderSummaryResponse(o.Id, o.Status.ToString(), o.TotalAmount, o.PlacedAt))
            .ToList();
    }
}

namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// A product in the quick-commerce essentials catalog. VendorId is null
/// for central dark-store products, or set for vendor-managed items.
/// </summary>
public sealed class Product : BaseEntity
{
    public Guid? VendorId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public string? Description { get; private set; }

    public decimal Price { get; private set; }

    public ProductCategory Category { get; private set; }

    public string SubCategory { get; private set; } = string.Empty;

    public string? Brand { get; private set; }

    public bool IsAvailable { get; private set; } = true;

    public int StockCount { get; private set; }

    public string? ImageUrl { get; private set; }

    public bool IsLateNightEssential { get; private set; }

    private Product()
    {
    }

    public static Product Create(
        string name,
        decimal price,
        ProductCategory category,
        string subCategory,
        int stockCount = 0,
        Guid? vendorId = null,
        string? description = null,
        string? brand = null,
        string? imageUrl = null,
        bool isLateNightEssential = false)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(subCategory);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(price, nameof(price));
        ArgumentOutOfRangeException.ThrowIfNegative(stockCount, nameof(stockCount));

        return new Product
        {
            Name = name,
            Price = price,
            Category = category,
            SubCategory = subCategory,
            StockCount = stockCount,
            VendorId = vendorId,
            Description = description,
            Brand = brand,
            ImageUrl = imageUrl,
            IsLateNightEssential = isLateNightEssential
        };
    }

    public void UpdateStock(int newStock)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(newStock, nameof(newStock));
        StockCount = newStock;
        MarkUpdated();
    }

    public void ToggleAvailability()
    {
        IsAvailable = !IsAvailable;
        MarkUpdated();
    }
}

/// <summary>
/// An order for quick-commerce essentials with flat-fee delivery.
/// </summary>
public sealed class ProductOrder : BaseEntity
{
    public Guid UserId { get; private set; }

    public Guid? VendorId { get; private set; }

    public ProductOrderStatus Status { get; private set; } = ProductOrderStatus.Placed;

    public decimal SubTotal { get; private set; }

    public decimal DeliveryFee { get; private set; }

    public decimal TotalAmount { get; private set; }

    public string Currency { get; private set; } = "INR";

    public string DeliveryAddress { get; private set; } = string.Empty;

    public GeoLocation DeliveryLocation { get; private set; } = GeoLocation.Zero;

    public PaymentStatus PaymentStatus { get; private set; } = PaymentStatus.Unpaid;

    public DateTimeOffset PlacedAt { get; private set; }

    public DateTimeOffset? DeliveredAt { get; private set; }

    private readonly List<ProductOrderItem> _items = [];
    public IReadOnlyCollection<ProductOrderItem> Items => _items.AsReadOnly();

    private ProductOrder()
    {
    }

    public static ProductOrder Create(
        Guid userId,
        string deliveryAddress,
        GeoLocation deliveryLocation,
        decimal deliveryFee,
        Guid? vendorId = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(deliveryAddress);
        ArgumentOutOfRangeException.ThrowIfNegative(deliveryFee, nameof(deliveryFee));

        return new ProductOrder
        {
            UserId = userId,
            VendorId = vendorId,
            DeliveryAddress = deliveryAddress,
            DeliveryLocation = deliveryLocation,
            DeliveryFee = deliveryFee,
            PlacedAt = DateTimeOffset.UtcNow
        };
    }

    public void AddItem(string name, int quantity, decimal unitPrice)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(quantity, 0, nameof(quantity));
        ArgumentOutOfRangeException.ThrowIfNegative(unitPrice, nameof(unitPrice));

        _items.Add(ProductOrderItem.Create(name, quantity, unitPrice));
        Recalculate();
        MarkUpdated();
    }

    public void Dispatch()
    {
        if (Status != ProductOrderStatus.Placed) throw new InvalidOperationException("Only placed orders can be dispatched.");
        Status = ProductOrderStatus.Dispatched;
        MarkUpdated();
    }

    public void Deliver()
    {
        if (Status != ProductOrderStatus.Dispatched) throw new InvalidOperationException("Only dispatched orders can be delivered.");
        Status = ProductOrderStatus.Delivered;
        DeliveredAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void Cancel()
    {
        if (Status is ProductOrderStatus.Delivered or ProductOrderStatus.Cancelled)
            throw new InvalidOperationException("Order already delivered or cancelled.");
        Status = ProductOrderStatus.Cancelled;
        MarkUpdated();
    }

    private void Recalculate()
    {
        SubTotal = _items.Sum(i => i.LineTotal);
        TotalAmount = SubTotal + DeliveryFee;
    }
}

public sealed class ProductOrderItem : BaseEntity
{
    public Guid ProductOrderId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public int Quantity { get; private set; }

    public decimal UnitPrice { get; private set; }

    public decimal LineTotal => Quantity * UnitPrice;

    private ProductOrderItem()
    {
    }

    public static ProductOrderItem Create(string name, int quantity, decimal unitPrice)
        => new()
        {
            Name = name,
            Quantity = quantity,
            UnitPrice = unitPrice
        };
}

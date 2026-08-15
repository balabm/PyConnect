namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// A food delivery order with transparent zero-commission pricing.
/// VendorPayout = SubTotal (100% to vendor), PlatformFee = 0.
/// </summary>
public sealed class FoodOrder : BaseEntity
{
    public Guid UserId { get; private set; }

    public Guid VendorId { get; private set; }

    public Guid? VenueId { get; private set; }

    public FoodOrderStatus Status { get; private set; } = FoodOrderStatus.Placed;

    public decimal SubTotal { get; private set; }

    public decimal VendorPayout { get; private set; }

    public decimal DeliveryFee { get; private set; }

    public decimal LateNightDriverBonus { get; private set; }

    public decimal PlatformFee { get; private set; }

    public decimal TotalAmount { get; private set; }

    public string Currency { get; private set; } = "INR";

    public DateTimeOffset PlacedAt { get; private set; }

    public DateTimeOffset? DeliveredAt { get; private set; }

    public string DeliveryAddress { get; private set; } = string.Empty;

    public GeoLocation DeliveryLocation { get; private set; } = GeoLocation.Zero;

    public PaymentMethod PaymentMethod { get; private set; } = PaymentMethod.Cash;

    public PaymentStatus PaymentStatus { get; private set; } = PaymentStatus.Unpaid;

    public string? Notes { get; private set; }

    private readonly List<FoodOrderItem> _items = [];
    public IReadOnlyCollection<FoodOrderItem> Items => _items.AsReadOnly();

    private FoodOrder()
    {
    }

    public static FoodOrder Create(
        Guid userId,
        Guid vendorId,
        string deliveryAddress,
        GeoLocation deliveryLocation,
        decimal subTotal,
        decimal deliveryFee,
        decimal lateNightDriverBonus,
        PaymentMethod paymentMethod,
        Guid? venueId = null,
        string? notes = null)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        ArgumentException.ThrowIfNullOrWhiteSpace(deliveryAddress);
        ArgumentOutOfRangeException.ThrowIfNegative(subTotal, nameof(subTotal));
        ArgumentOutOfRangeException.ThrowIfNegative(deliveryFee, nameof(deliveryFee));
        ArgumentOutOfRangeException.ThrowIfNegative(lateNightDriverBonus, nameof(lateNightDriverBonus));

        return new FoodOrder
        {
            UserId = userId,
            VendorId = vendorId,
            VenueId = venueId,
            DeliveryAddress = deliveryAddress,
            DeliveryLocation = deliveryLocation,
            SubTotal = subTotal,
            VendorPayout = subTotal,
            DeliveryFee = deliveryFee,
            LateNightDriverBonus = lateNightDriverBonus,
            PlatformFee = 0m,
            TotalAmount = subTotal + deliveryFee + lateNightDriverBonus,
            PaymentMethod = paymentMethod,
            PlacedAt = DateTimeOffset.UtcNow,
            Notes = notes
        };
    }

    public void AddItem(string name, int quantity, decimal unitPrice, string? specialInstructions = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(quantity, 0, nameof(quantity));
        ArgumentOutOfRangeException.ThrowIfNegative(unitPrice, nameof(unitPrice));

        _items.Add(FoodOrderItem.Create(name, quantity, unitPrice, specialInstructions));
        Recalculate();
        MarkUpdated();
    }

    public void Accept()
    {
        if (Status != FoodOrderStatus.Placed) throw new InvalidOperationException("Only placed orders can be accepted.");
        Status = FoodOrderStatus.Accepted;
        MarkUpdated();
    }

    public void StartPreparing()
    {
        if (Status != FoodOrderStatus.Accepted) throw new InvalidOperationException("Only accepted orders can start preparing.");
        Status = FoodOrderStatus.Preparing;
        MarkUpdated();
    }

    public void Dispatch()
    {
        if (Status != FoodOrderStatus.Preparing) throw new InvalidOperationException("Only prepared orders can be dispatched.");
        Status = FoodOrderStatus.OutForDelivery;
        MarkUpdated();
    }

    public void Deliver()
    {
        if (Status != FoodOrderStatus.OutForDelivery) throw new InvalidOperationException("Only out-for-delivery orders can be delivered.");
        Status = FoodOrderStatus.Delivered;
        DeliveredAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void Cancel()
    {
        if (Status is FoodOrderStatus.Delivered or FoodOrderStatus.Cancelled)
            throw new InvalidOperationException("Order already delivered or cancelled.");
        Status = FoodOrderStatus.Cancelled;
        MarkUpdated();
    }

    /// <summary>
    /// Removes an item from the order and recalculates the total. Used for
    /// partial fulfillment when a vendor discovers an item is out of stock
    /// after accepting the order. The price difference is refunded to the
    /// customer via Razorpay. Only valid for orders that have not been
    /// delivered or cancelled.
    /// </summary>
    /// <returns>The refund amount (price of the removed item × quantity).</returns>
    public decimal RemoveItem(Guid itemId)
    {
        if (Status is FoodOrderStatus.Delivered or FoodOrderStatus.Cancelled)
            throw new InvalidOperationException("Cannot modify a delivered or cancelled order.");

        var item = _items.FirstOrDefault(i => i.Id == itemId)
            ?? throw new InvalidOperationException("Item not found in this order.");

        var refundAmount = item.LineTotal;
        _items.Remove(item);
        Recalculate();
        MarkUpdated();
        return refundAmount;
    }

    public void RecordPayment(PaymentStatus status)
    {
        PaymentStatus = status;
        MarkUpdated();
    }

    private void Recalculate()
    {
        SubTotal = _items.Sum(i => i.LineTotal);
        VendorPayout = SubTotal;
        TotalAmount = SubTotal + DeliveryFee + LateNightDriverBonus + PlatformFee;
    }
}

public sealed class FoodOrderItem : BaseEntity
{
    public Guid FoodOrderId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public int Quantity { get; private set; }

    public decimal UnitPrice { get; private set; }

    public decimal LineTotal => Quantity * UnitPrice;

    public string? SpecialInstructions { get; private set; }

    private FoodOrderItem()
    {
    }

    public static FoodOrderItem Create(string name, int quantity, decimal unitPrice, string? specialInstructions = null)
        => new()
        {
            Name = name,
            Quantity = quantity,
            UnitPrice = unitPrice,
            SpecialInstructions = specialInstructions
        };
}

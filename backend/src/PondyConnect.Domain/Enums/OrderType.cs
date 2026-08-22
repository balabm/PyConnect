namespace PondyConnect.Domain.Enums;

/// <summary>
/// Distinguishes between delivery, dine-in, and takeaway orders.
/// Dine-in orders bypass the captain dispatch system entirely
/// and route directly to the partner KDS tablet.
/// </summary>
public enum OrderType
{
    Delivery = 1,
    DineIn = 2,
    Takeaway = 3
}

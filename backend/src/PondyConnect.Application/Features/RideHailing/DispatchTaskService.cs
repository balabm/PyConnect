namespace PondyConnect.Application.Features.RideHailing;

using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

public sealed class DispatchTaskService
{
    private readonly IApplicationDbContext _context;

    public DispatchTaskService(IApplicationDbContext context) => _context = context;

    public DispatchTask CreateFromRide(RideRequest ride)
    {
        var task = DispatchTask.Create(
            taskType: DispatchTaskType.Ride,
            pickupLocation: ride.PickupLocation,
            dropoffLocation: ride.DropoffLocation,
            pickupAddress: ride.PickupAddress,
            dropoffAddress: ride.DropoffAddress,
            driverEarnings: ride.IsSos ? ride.SosDriverPayout : ride.Fare,
            sourceEntityId: ride.Id);

        _context.DispatchTasks.Add(task);
        return task;
    }

    public DispatchTask CreateFromFoodOrder(FoodOrder order)
    {
        var earnings = order.DeliveryFee + order.LateNightDriverBonus;

        var task = DispatchTask.Create(
            taskType: DispatchTaskType.FoodDelivery,
            pickupLocation: GeoLocation.Zero,
            dropoffLocation: GeoLocation.Zero,
            pickupAddress: "Vendor location",
            dropoffAddress: order.DeliveryAddress,
            driverEarnings: earnings,
            sourceEntityId: order.Id);

        _context.DispatchTasks.Add(task);
        return task;
    }
}

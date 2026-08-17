namespace PondyConnect.Api.Services;

using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Api.Hubs;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Dispatch;
using PondyConnect.Application.Features.RideHailing;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// Dispatches food delivery pickup offers to nearby online drivers via
/// SignalR (DriverHub). Called when a food order transitions to OutForDelivery.
/// Uses the vendor's linked venue location as the pickup point, falling back
/// to the delivery location if no venue is linked.
///
/// Also creates a <see cref="Domain.Entities.DispatchTask"/> so the driver
/// can see, accept, and progress through the delivery lifecycle via the REST
/// API (GET /api/driver/tasks, POST accept, arrived-at-store, out-for-delivery,
/// complete).
/// </summary>
public sealed class FoodDeliveryDispatchService : IFoodDeliveryDispatchService
{
    private readonly IHubContext<DriverHub> _driverHub;
    private readonly IApplicationDbContext _context;
    private readonly DriverLocationStore _locationStore;
    private readonly DispatchTaskService _dispatchTaskService;
    private readonly BatchingService _batchingService;

    public FoodDeliveryDispatchService(
        IHubContext<DriverHub> driverHub,
        IApplicationDbContext context,
        DriverLocationStore locationStore,
        DispatchTaskService dispatchTaskService,
        BatchingService batchingService)
    {
        _driverHub = driverHub;
        _context = context;
        _locationStore = locationStore;
        _dispatchTaskService = dispatchTaskService;
        _batchingService = batchingService;
    }

    /// <summary>
    /// Broadcast a food delivery offer to nearby online drivers.
    /// Returns the list of driver IDs the offer was sent to.
    /// </summary>
    public async Task<IReadOnlyList<Guid>> DispatchFoodOrderAsync(
        Guid foodOrderId,
        CancellationToken cancellationToken = default)
    {
        var order = await _context.FoodOrders
            .FirstOrDefaultAsync(o => o.Id == foodOrderId, cancellationToken);
        if (order is null) return Array.Empty<Guid>();

        // Idempotency: only process once per food order.
        var existingTask = await _context.DispatchTasks
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.SourceEntityId == order.Id && t.TaskType == Domain.Enums.DispatchTaskType.FoodDelivery, cancellationToken);

        if (existingTask is not null)
            return Array.Empty<Guid>();

        // Resolve pickup location: vendor's linked venue, or fall back to delivery area
        GeoLocation pickupLocation;
        string pickupAddress;

        var venue = await _context.Venues
            .AsNoTracking()
            .FirstOrDefaultAsync(v => v.VendorId == order.VendorId && v.IsActive, cancellationToken);

        if (venue is not null)
        {
            pickupLocation = venue.Location;
            pickupAddress = venue.Address ?? venue.Name;
        }
        else
        {
            pickupLocation = order.DeliveryLocation;
            pickupAddress = order.DeliveryAddress;
        }

        var dropoffLocation = order.DeliveryLocation;

        // Try to batch with an active delivery from the same restaurant/route.
        var batchResult = await _batchingService.TryBatchOrderAsync(
            order.VendorId,
            pickupLocation.Latitude,
            pickupLocation.Longitude,
            dropoffLocation.Latitude,
            dropoffLocation.Longitude,
            cancellationToken);

        if (batchResult.Batched)
        {
            var candidate = await _context.DispatchTasks
                .FirstOrDefaultAsync(t => t.Id == batchResult.TaskIds![0], cancellationToken);

            if (candidate is not null)
            {
                candidate.AssignToBatch(batchResult.BatchGroupId!.Value);

                var batchedTask = _dispatchTaskService.CreateFromFoodOrder(order, pickupLocation, dropoffLocation);
                batchedTask.AssignToBatch(batchResult.BatchGroupId.Value);
                batchedTask.Assign(batchResult.DriverId!.Value);

                await _context.SaveChangesAsync(cancellationToken);

                // Notify only the already-assigned driver about the new batch order.
                var vendor = await _context.Vendors
                    .AsNoTracking()
                    .FirstOrDefaultAsync(v => v.Id == order.VendorId, cancellationToken);

                var vendorName = vendor?.Name ?? "Unknown Restaurant";

                var offer = new FoodDeliveryOfferBroadcast(
                    OrderId: order.Id,
                    VendorName: vendorName,
                    PickupAddress: pickupAddress,
                    DeliveryAddress: order.DeliveryAddress,
                    DeliveryFee: order.DeliveryFee,
                    LateNightDriverBonus: order.LateNightDriverBonus,
                    TotalAmount: order.TotalAmount,
                    PaymentMethod: order.PaymentMethod.ToString(),
                    ExpiresIn: 20);

                await _driverHub.Clients.Group($"driver:{batchResult.DriverId.Value}")
                    .SendAsync("FoodDeliveryOffer", offer, cancellationToken);

                return new[] { batchResult.DriverId.Value };
            }
        }

        // No batch match — create a normal dispatch task and broadcast to nearby drivers.
        _dispatchTaskService.CreateFromFoodOrder(order, pickupLocation, dropoffLocation);
        await _context.SaveChangesAsync(cancellationToken);

        var nearby = _locationStore.GetNearby(pickupLocation, radiusKm: 3.0, vehicleTypeFilter: null, maxCount: 5);

        if (nearby.Count == 0)
        {
            // Expand radius once
            nearby = _locationStore.GetNearby(pickupLocation, radiusKm: 5.0, vehicleTypeFilter: null, maxCount: 5);
        }

        if (nearby.Count == 0)
            return Array.Empty<Guid>();

        var broadcastVendor = await _context.Vendors
            .AsNoTracking()
            .FirstOrDefaultAsync(v => v.Id == order.VendorId, cancellationToken);

        var broadcastVendorName = broadcastVendor?.Name ?? "Unknown Restaurant";

        var broadcastOffer = new FoodDeliveryOfferBroadcast(
            OrderId: order.Id,
            VendorName: broadcastVendorName,
            PickupAddress: pickupAddress,
            DeliveryAddress: order.DeliveryAddress,
            DeliveryFee: order.DeliveryFee,
            LateNightDriverBonus: order.LateNightDriverBonus,
            TotalAmount: order.TotalAmount,
            PaymentMethod: order.PaymentMethod.ToString(),
            ExpiresIn: 20);

        foreach (var driver in nearby)
        {
            await _driverHub.Clients.Group($"driver:{driver.DriverId}")
                .SendAsync("FoodDeliveryOffer", broadcastOffer, cancellationToken);
        }

        return nearby.Select(d => d.DriverId).ToList();
    }
}

/// <summary>
/// SignalR broadcast payload for a food delivery offer sent to specific drivers.
/// </summary>
public sealed record FoodDeliveryOfferBroadcast(
    Guid OrderId,
    string VendorName,
    string PickupAddress,
    string DeliveryAddress,
    decimal DeliveryFee,
    decimal LateNightDriverBonus,
    decimal TotalAmount,
    string PaymentMethod,
    int ExpiresIn);

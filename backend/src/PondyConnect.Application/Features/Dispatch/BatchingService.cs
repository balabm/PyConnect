namespace PondyConnect.Application.Features.Dispatch;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Geo;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

public sealed record BatchResult(
    bool Batched,
    Guid? DriverId = null,
    List<Guid>? TaskIds = null,
    Guid? BatchGroupId = null);

public sealed class BatchingService
{
    private const double SameRestaurantDistanceThresholdMeters = 500.0;
    private const double DropoffAngleThresholdDegrees = 15.0;

    private readonly IApplicationDbContext _context;
    private readonly ILogger<BatchingService> _logger;

    public BatchingService(IApplicationDbContext context, ILogger<BatchingService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<BatchResult> TryBatchOrderAsync(
        Guid restaurantId,
        double restaurantLat,
        double restaurantLng,
        double dropoffLat,
        double dropoffLng,
        CancellationToken ct)
    {
        var candidates = await _context.DispatchTasks
            .AsNoTracking()
            .Where(t => t.TaskType == DispatchTaskType.FoodDelivery
                && (t.Status == DispatchTaskStatus.InProgress
                    || t.Status == DispatchTaskStatus.ArrivedAtStore
                    || t.Status == DispatchTaskStatus.OutForDelivery)
                && t.DriverId != null
                && t.SourceEntityId != null)
            .ToListAsync(ct);

        if (candidates.Count == 0)
            return new BatchResult(false);

        foreach (var candidate in candidates)
        {
            var candidateOrder = await _context.FoodOrders
                .AsNoTracking()
                .FirstOrDefaultAsync(o => o.Id == candidate.SourceEntityId, ct);

            if (candidateOrder is null)
                continue;

            var sameRestaurant = restaurantId == candidateOrder.VendorId;

            (double lat, double lng) candidatePickup;
            var venue = await _context.Venues
                .AsNoTracking()
                .FirstOrDefaultAsync(v => v.VendorId == candidateOrder.VendorId && v.IsActive, ct);

            if (venue is not null)
            {
                candidatePickup = (venue.Location.Latitude, venue.Location.Longitude);
            }
            else
            {
                candidatePickup = (candidateOrder.DeliveryLocation.Latitude, candidateOrder.DeliveryLocation.Longitude);
            }

            if (!sameRestaurant)
            {
                var distance = GeoCalculator.HaversineDistance(
                    restaurantLat, restaurantLng,
                    candidatePickup.lat, candidatePickup.lng);

                if (distance > SameRestaurantDistanceThresholdMeters)
                    continue;
            }

            var candidateDropoff = candidateOrder.DeliveryLocation;

            var routeBearing = GeoCalculator.Bearing(
                candidatePickup.lat, candidatePickup.lng,
                candidateDropoff.Latitude, candidateDropoff.Longitude);

            var newDropoffBearing = GeoCalculator.Bearing(
                candidatePickup.lat, candidatePickup.lng,
                dropoffLat, dropoffLng);

            var angleDifference = GeoCalculator.AngleDifference(routeBearing, newDropoffBearing);

            if (angleDifference <= DropoffAngleThresholdDegrees)
            {
                var batchGroupId = candidate.BatchGroupId ?? Guid.NewGuid();

                _logger.LogInformation(
                    "Batched new order for restaurant {RestaurantId} with driver {DriverId} in batch {BatchGroupId}",
                    restaurantId, candidate.DriverId, batchGroupId);

                return new BatchResult(
                    true,
                    candidate.DriverId,
                    [candidate.Id],
                    batchGroupId);
            }
        }

        return new BatchResult(false);
    }
}

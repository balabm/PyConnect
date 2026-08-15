namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

/// <summary>
/// Unified activity feed for the authenticated user. Aggregates stays, food
/// orders, rides and scooter rentals into a single chronologically sorted
/// timeline.
/// </summary>
[ApiController]
[Route("api/activity")]
[Authorize]
public sealed class ActivityController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ActivityController(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    /// <summary>
    /// Returns a unified, chronologically sorted list of all activity for the
    /// current user (stays, food, rides, rentals).
    /// </summary>
    [HttpGet("all")]
    [ProducesResponseType(typeof(IReadOnlyList<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<object>>> GetAll(CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return Unauthorized(new { Message = "User not authenticated." });

        var activities = new List<ActivityItem>();

        // ── Stays (Homestay service bookings) ──
        var stays = await _context.ServiceBookings.AsNoTracking()
            .Where(b => b.UserId == userId.Value && b.ServiceType == ServiceType.Homestay)
            .Select(b => new
            {
                b.Id,
                b.Status,
                b.TotalAmount,
                b.CreatedAt,
                b.CheckInDate,
                b.CheckOutDate
            })
            .ToListAsync(cancellationToken);

        foreach (var s in stays)
        {
            var subtitle = s.CheckInDate.HasValue && s.CheckOutDate.HasValue
                ? $"{s.CheckInDate:yyyy-MM-dd} → {s.CheckOutDate:yyyy-MM-dd}"
                : "Dates pending";
            activities.Add(new ActivityItem(
                s.Id,
                "Stay",
                s.Status.ToString(),
                "Homestay Booking",
                subtitle,
                s.TotalAmount,
                s.CreatedAt));
        }

        // ── Food orders (title = vendor name, subtitle = item names) ──
        var foodOrders = await _context.FoodOrders.AsNoTracking()
            .Where(f => f.UserId == userId.Value)
            .Select(f => new
            {
                f.Id,
                f.Status,
                f.TotalAmount,
                f.CreatedAt,
                f.VendorId,
                ItemCount = _context.FoodOrderItems.AsNoTracking().Count(i => i.FoodOrderId == f.Id),
                ItemNames = _context.FoodOrderItems.AsNoTracking()
                    .Where(i => i.FoodOrderId == f.Id)
                    .Select(i => i.Name)
                    .ToList()
            })
            .ToListAsync(cancellationToken);

        var foodVendorIds = foodOrders.Select(f => f.VendorId).Distinct().ToList();
        var vendorNames = await _context.Vendors.AsNoTracking()
            .Where(v => foodVendorIds.Contains(v.Id))
            .ToDictionaryAsync(v => v.Id, v => v.Name, cancellationToken);

        foreach (var f in foodOrders)
        {
            var title = vendorNames.TryGetValue(f.VendorId, out var name) ? name : "Food Order";
            // Show up to 3 item names, then "+N more" if there are more.
            var names = f.ItemNames;
            string subtitle;
            if (names.Count == 0)
            {
                subtitle = $"{f.ItemCount} item{(f.ItemCount == 1 ? "" : "s")}";
            }
            else if (names.Count <= 3)
            {
                subtitle = string.Join(", ", names);
            }
            else
            {
                subtitle = $"{string.Join(", ", names.Take(3))} +{names.Count - 3} more";
            }
            activities.Add(new ActivityItem(
                f.Id,
                "Food",
                f.Status.ToString(),
                title,
                subtitle,
                f.TotalAmount,
                f.CreatedAt));
        }

        // ── Rides (title = vehicleType, subtitle = pickup → dropoff) ──
        var rides = await _context.RideRequests.AsNoTracking()
            .Where(r => r.UserId == userId.Value)
            .Select(r => new
            {
                r.Id,
                r.Status,
                r.TotalAmount,
                r.CreatedAt,
                r.VehicleType,
                r.PickupAddress,
                r.DropoffAddress
            })
            .ToListAsync(cancellationToken);

        foreach (var r in rides)
        {
            activities.Add(new ActivityItem(
                r.Id,
                "Ride",
                r.Status.ToString(),
                r.VehicleType.ToString(),
                $"{r.PickupAddress} → {r.DropoffAddress}",
                r.TotalAmount,
                r.CreatedAt));
        }

        // ── Scooter rentals (title = "Scooter Rental", subtitle = model) ──
        var rentals = await _context.ScooterRentals.AsNoTracking()
            .Where(r => r.UserId == userId.Value)
            .Select(r => new
            {
                r.Id,
                r.Status,
                r.TotalAmount,
                r.CreatedAt,
                r.VehicleName
            })
            .ToListAsync(cancellationToken);

        foreach (var r in rentals)
        {
            activities.Add(new ActivityItem(
                r.Id,
                "Rental",
                r.Status.ToString(),
                "Scooter Rental",
                r.VehicleName,
                r.TotalAmount,
                r.CreatedAt));
        }

        // Sort by createdAt descending
        var sorted = activities
            .OrderByDescending(a => a.CreatedAt)
            .Select(a => (object)new
            {
                id = a.Id,
                type = a.Type,
                status = a.Status,
                title = a.Title,
                subtitle = a.Subtitle,
                amount = a.Amount,
                createdAt = a.CreatedAt
            })
            .ToList();

        return Ok(sorted);
    }

    private sealed record ActivityItem(
        Guid Id,
        string Type,
        string Status,
        string Title,
        string Subtitle,
        decimal Amount,
        DateTimeOffset CreatedAt);
}

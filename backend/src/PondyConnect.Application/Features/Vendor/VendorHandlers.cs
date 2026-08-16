namespace PondyConnect.Application.Features.Vendor;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class GetVendorDashboardHandler : IRequestHandler<GetVendorDashboardQuery, VendorDashboardResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetVendorDashboardHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<VendorDashboardResponse> Handle(GetVendorDashboardQuery request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken);
        if (vendorId == null)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var date = request.Date ?? DateOnly.FromDateTime(DateTime.UtcNow.AddMinutes(330)); // IST
        var startOfDay = new DateTimeOffset(date.ToDateTime(TimeOnly.MinValue).AddMinutes(-330), TimeSpan.Zero);
        var endOfDay = new DateTimeOffset(date.ToDateTime(TimeOnly.MaxValue).AddMinutes(-330), TimeSpan.Zero);

        // Aggregate from all booking types
        var venueBookings = _context.IsPostgreSQL
            ? await _context.ServiceBookings
                .Where(b => b.VendorId == vendorId && b.ScheduledFor >= startOfDay && b.ScheduledFor <= endOfDay)
                .Select(b => new { b.Id, Type = "Nightlife", b.ScheduledFor, b.Status, b.TotalAmount, b.PaymentStatus })
                .ToListAsync(cancellationToken)
            : (await _context.ServiceBookings
                .Where(b => b.VendorId == vendorId)
                .Select(b => new { b.Id, Type = "Nightlife", b.ScheduledFor, b.Status, b.TotalAmount, b.PaymentStatus })
                .ToListAsync(cancellationToken))
                .Where(b => b.ScheduledFor >= startOfDay && b.ScheduledFor <= endOfDay)
                .ToList();

        var transitTrips = _context.IsPostgreSQL
            ? await _context.TransitTrips
                .Where(t => t.VendorId == vendorId && t.ArrivalAt >= startOfDay && t.ArrivalAt <= endOfDay)
                .Select(t => new { t.Id, Type = "Transit", ScheduledFor = t.ArrivalAt, t.Status, t.Price, t.PaymentStatus })
                .ToListAsync(cancellationToken)
            : (await _context.TransitTrips
                .Where(t => t.VendorId == vendorId)
                .Select(t => new { t.Id, Type = "Transit", ScheduledFor = t.ArrivalAt, t.Status, t.Price, t.PaymentStatus })
                .ToListAsync(cancellationToken))
                .Where(t => t.ScheduledFor >= startOfDay && t.ScheduledFor <= endOfDay)
                .ToList();

        var luggageDropOffs = _context.IsPostgreSQL
            ? await _context.LuggageDropOffs
                .Where(l => l.VendorId == vendorId && l.ScheduledFor >= startOfDay && l.ScheduledFor <= endOfDay)
                .Select(l => new { l.Id, Type = "Luggage", l.ScheduledFor, l.Status, l.TotalAmount, l.PaymentStatus })
                .ToListAsync(cancellationToken)
            : (await _context.LuggageDropOffs
                .Where(l => l.VendorId == vendorId)
                .Select(l => new { l.Id, Type = "Luggage", l.ScheduledFor, l.Status, l.TotalAmount, l.PaymentStatus })
                .ToListAsync(cancellationToken))
                .Where(l => l.ScheduledFor >= startOfDay && l.ScheduledFor <= endOfDay)
                .ToList();

        var rentals = _context.IsPostgreSQL
            ? await _context.ScooterRentals
                .Where(r => r.VendorId == vendorId && r.RentalStart >= startOfDay && r.RentalStart <= endOfDay)
                .Select(r => new { r.Id, Type = "Rental", ScheduledFor = r.RentalStart, r.Status, r.TotalAmount, r.PaymentStatus })
                .ToListAsync(cancellationToken)
            : (await _context.ScooterRentals
                .Where(r => r.VendorId == vendorId)
                .Select(r => new { r.Id, Type = "Rental", ScheduledFor = r.RentalStart, r.Status, r.TotalAmount, r.PaymentStatus })
                .ToListAsync(cancellationToken))
                .Where(r => r.ScheduledFor >= startOfDay && r.ScheduledFor <= endOfDay)
                .ToList();

        var allBookings = venueBookings
            .Select(b => new VendorBookingSummary(b.Id, b.Type, "User", "N/A", b.ScheduledFor, b.Status.ToString(), b.TotalAmount, b.PaymentStatus.ToString()))
            .Concat(transitTrips.Select(t => new VendorBookingSummary(t.Id, t.Type, "User", "N/A", t.ScheduledFor, t.Status.ToString(), t.Price, t.PaymentStatus.ToString())))
            .Concat(luggageDropOffs.Select(l => new VendorBookingSummary(l.Id, l.Type, "User", "N/A", l.ScheduledFor, l.Status.ToString(), l.TotalAmount, l.PaymentStatus.ToString())))
            .Concat(rentals.Select(r => new VendorBookingSummary(r.Id, r.Type, "User", "N/A", r.ScheduledFor, r.Status.ToString(), r.TotalAmount, r.PaymentStatus.ToString())))
            .OrderByDescending(b => b.ScheduledFor)
            .ToList();

        var todayBookings = allBookings.Count;
        var pending = allBookings.Count(b => b.Status == "Pending" || b.Status == "Requested" || b.Status == "Reserved");
        var confirmed = allBookings.Count(b => b.Status == "Confirmed" || b.Status == "Assigned");
        var completed = allBookings.Count(b => b.Status == "Completed");
        var revenue = allBookings.Where(b => b.PaymentStatus == "Captured").Sum(b => b.Amount);

        return new VendorDashboardResponse(
            todayBookings,
            pending,
            confirmed,
            completed,
            revenue,
            allBookings.Take(10).ToList());
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        // In Phase 2, vendor is linked to user via VendorId claim or we look up by user phone
        var userId = _currentUser.UserId;
        if (userId == null)
            return null;

        // Simple lookup: vendor with matching contact phone = user phone
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return null;

        return await _context.Vendors
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

public sealed class GetVendorBookingsHandler : IRequestHandler<GetVendorBookingsQuery, VendorBookingsResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetVendorBookingsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<VendorBookingsResponse> Handle(GetVendorBookingsQuery request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken);
        if (vendorId == null)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var date = request.Date ?? DateOnly.FromDateTime(DateTime.UtcNow.AddMinutes(330));
        var startOfDay = new DateTimeOffset(date.ToDateTime(TimeOnly.MinValue).AddMinutes(-330), TimeSpan.Zero);
        var endOfDay = new DateTimeOffset(date.ToDateTime(TimeOnly.MaxValue).AddMinutes(-330), TimeSpan.Zero);

        var venueBookings = _context.IsPostgreSQL
            ? await _context.ServiceBookings
                .Where(b => b.VendorId == vendorId && b.ScheduledFor >= startOfDay && b.ScheduledFor <= endOfDay)
                .ToListAsync(cancellationToken)
            : await _context.ServiceBookings
                .Where(b => b.VendorId == vendorId)
                .ToListAsync(cancellationToken);
        if (request.Status.HasValue)
            venueBookings = venueBookings.Where(b => b.Status == request.Status.Value).ToList();

        var transitTrips = _context.IsPostgreSQL
            ? await _context.TransitTrips
                .Where(t => t.VendorId == vendorId && t.ArrivalAt >= startOfDay && t.ArrivalAt <= endOfDay)
                .ToListAsync(cancellationToken)
            : await _context.TransitTrips
                .Where(t => t.VendorId == vendorId)
                .ToListAsync(cancellationToken);

        var luggageDropOffs = _context.IsPostgreSQL
            ? await _context.LuggageDropOffs
                .Where(l => l.VendorId == vendorId && l.ScheduledFor >= startOfDay && l.ScheduledFor <= endOfDay)
                .ToListAsync(cancellationToken)
            : await _context.LuggageDropOffs
                .Where(l => l.VendorId == vendorId)
                .ToListAsync(cancellationToken);

        var rentals = _context.IsPostgreSQL
            ? await _context.ScooterRentals
                .Where(r => r.VendorId == vendorId && r.RentalStart >= startOfDay && r.RentalStart <= endOfDay)
                .ToListAsync(cancellationToken)
            : await _context.ScooterRentals
                .Where(r => r.VendorId == vendorId)
                .ToListAsync(cancellationToken);

        var allSummaries = new List<VendorBookingSummary>();

        if (!_context.IsPostgreSQL)
        {
            venueBookings = venueBookings.Where(b => b.ScheduledFor >= startOfDay && b.ScheduledFor <= endOfDay).ToList();
            transitTrips = transitTrips.Where(t => t.ArrivalAt >= startOfDay && t.ArrivalAt <= endOfDay).ToList();
            luggageDropOffs = luggageDropOffs.Where(l => l.ScheduledFor >= startOfDay && l.ScheduledFor <= endOfDay).ToList();
            rentals = rentals.Where(r => r.RentalStart >= startOfDay && r.RentalStart <= endOfDay).ToList();
        }

        foreach (var b in venueBookings)
            allSummaries.Add(new VendorBookingSummary(b.Id, "Nightlife", "User", "N/A", b.ScheduledFor, b.Status.ToString(), b.TotalAmount, b.PaymentStatus.ToString()));
        
        foreach (var t in transitTrips)
            allSummaries.Add(new VendorBookingSummary(t.Id, "Transit", "User", "N/A", t.ArrivalAt, t.Status.ToString(), t.Price, t.PaymentStatus.ToString(), t.DriverName, t.VehiclePlate));
        
        foreach (var l in luggageDropOffs)
            allSummaries.Add(new VendorBookingSummary(l.Id, "Luggage", "User", "N/A", l.ScheduledFor, l.Status.ToString(), l.TotalAmount, l.PaymentStatus.ToString()));
        
        foreach (var r in rentals)
            allSummaries.Add(new VendorBookingSummary(r.Id, "Rental", "User", "N/A", r.RentalStart, r.Status.ToString(), r.TotalAmount, r.PaymentStatus.ToString()));

        var ordered = allSummaries.OrderByDescending(b => b.ScheduledFor).ToList();
        var paged = ordered.Skip((request.Page - 1) * request.PageSize).Take(request.PageSize).ToList();

        return new VendorBookingsResponse(paged, ordered.Count);
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return null;

        return await _context.Vendors
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

// ── Vendor Booking Status Update ──

public sealed record UpdateVendorBookingStatusCommand(
    Guid BookingId,
    string ServiceType,
    string NewStatus) : IRequest<Unit>;

public sealed class UpdateVendorBookingStatusHandler : IRequestHandler<UpdateVendorBookingStatusCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public UpdateVendorBookingStatusHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(UpdateVendorBookingStatusCommand request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken)
            ?? throw new UnauthorizedAccessException("Vendor profile not found.");

        switch (request.ServiceType)
        {
            case "Nightlife":
                {
                    var booking = await _context.ServiceBookings
                        .FirstOrDefaultAsync(b => b.Id == request.BookingId && b.VendorId == vendorId, cancellationToken)
                        ?? throw new InvalidOperationException("Booking not found or not owned by vendor.");

                    switch (request.NewStatus)
                    {
                        case "Confirmed": booking.Confirm(); break;
                        case "CheckedIn": booking.CheckIn(); break;
                        case "Completed": booking.Complete(); break;
                        case "Cancelled": booking.Cancel(); break;
                        default: throw new InvalidOperationException($"Invalid status '{request.NewStatus}' for Nightlife booking.");
                    }
                    break;
                }
            case "Transit":
                {
                    var trip = await _context.TransitTrips
                        .FirstOrDefaultAsync(t => t.Id == request.BookingId && t.VendorId == vendorId, cancellationToken)
                        ?? throw new InvalidOperationException("Transit trip not found or not owned by vendor.");

                    switch (request.NewStatus)
                    {
                        case "EnRoute": trip.Start(); break;
                        case "Completed": trip.Complete(); break;
                        case "Cancelled": trip.Cancel(); break;
                        default: throw new InvalidOperationException($"Invalid status '{request.NewStatus}' for Transit trip.");
                    }
                    break;
                }
            case "Luggage":
                {
                    var dropOff = await _context.LuggageDropOffs
                        .FirstOrDefaultAsync(l => l.Id == request.BookingId && l.VendorId == vendorId, cancellationToken)
                        ?? throw new InvalidOperationException("Luggage drop-off not found or not owned by vendor.");

                    switch (request.NewStatus)
                    {
                        case "Dropped": dropOff.MarkDropped(); break;
                        case "Collected": dropOff.MarkCollected(); break;
                        case "Cancelled": dropOff.Cancel(); break;
                        default: throw new InvalidOperationException($"Invalid status '{request.NewStatus}' for Luggage booking.");
                    }
                    break;
                }
            case "Rental":
                {
                    var rental = await _context.ScooterRentals
                        .FirstOrDefaultAsync(r => r.Id == request.BookingId && r.VendorId == vendorId, cancellationToken)
                        ?? throw new InvalidOperationException("Rental not found or not owned by vendor.");

                    switch (request.NewStatus)
                    {
                        case "Active": rental.StartRental(); break;
                        case "Returned": rental.Return(); break;
                        case "Cancelled": rental.Cancel(); break;
                        default: throw new InvalidOperationException($"Invalid status '{request.NewStatus}' for Rental.");
                    }
                    break;
                }
            default:
                throw new InvalidOperationException($"Unknown service type '{request.ServiceType}'.");
        }

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return null;

        return await _context.Vendors
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

public sealed class ListVendorsHandler : IRequestHandler<ListVendorsQuery, IReadOnlyList<VendorResponse>>
{
    private readonly IApplicationDbContext _context;

    public ListVendorsHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<VendorResponse>> Handle(ListVendorsQuery request, CancellationToken cancellationToken)
    {
        var query = _context.Vendors.AsNoTracking();
        if (request.OnlyApproved)
            query = query.Where(v => v.IsApproved && v.IsActive);

        // Fetch from DB first, then filter by category in memory (SQLite workaround
        // for HasConversion<string>() enum columns failing parameterized comparisons).
        if (_context.IsPostgreSQL)
        {
            if (request.Category.HasValue)
                query = query.Where(v => v.Category == request.Category.Value);
            if (request.FoodVendorsOnly)
                query = query.Where(v => v.Category == VendorCategory.Restaurant
                    || v.Category == VendorCategory.Cafe
                    || v.Category == VendorCategory.Pizzeria);
        }

        var vendors = await query
            .Select(v => new
            {
                v.Id, v.Name, v.Category, v.ContactPhone, v.MerchantReference,
                v.CuisineType, v.Rating, v.ImageUrl, v.Description, v.DeliveryFee, v.PrepTimeMinutes,
                v.IsAcceptingOrders
            })
            .ToListAsync(cancellationToken);

        if (!_context.IsPostgreSQL)
        {
            if (request.Category.HasValue)
                vendors = vendors.Where(v => v.Category == request.Category.Value).ToList();
            if (request.FoodVendorsOnly)
                vendors = vendors.Where(v => v.Category == VendorCategory.Restaurant
                    || v.Category == VendorCategory.Cafe
                    || v.Category == VendorCategory.Pizzeria).ToList();
        }

        vendors = vendors.OrderBy(v => v.Name).ToList();

        var vendorIds = vendors.Select(v => v.Id).ToList();
        var menuCounts = await _context.MenuItems
            .Where(m => vendorIds.Contains(m.VendorId) && m.IsAvailable)
            .GroupBy(m => m.VendorId)
            .Select(g => new { VendorId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.VendorId, g => g.Count, cancellationToken);

        return vendors.Select(v => new VendorResponse(
            v.Id, v.Name, v.Category.ToString(), v.ContactPhone, v.MerchantReference,
            v.CuisineType, v.Rating, v.ImageUrl, v.Description, v.DeliveryFee, v.PrepTimeMinutes,
            menuCounts.GetValueOrDefault(v.Id, 0), v.IsAcceptingOrders)).ToList();
    }
}
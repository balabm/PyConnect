namespace PondyConnect.Application.Features.Vendor;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

public sealed class CreateVendorVenueHandler : IRequestHandler<CreateVendorVenueCommand, CreateVendorVenueResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateVendorVenueHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<CreateVendorVenueResponse> Handle(CreateVendorVenueCommand request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken);
        if (vendorId == null)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var venue = Venue.Create(
            request.Name,
            request.Category,
            GeoLocation.Create(request.Latitude, request.Longitude),
            request.MaxCapacity,
            vendorId: vendorId,
            description: request.Description,
            address: request.Address);

        foreach (var day in request.OperatingHours ?? [])
            venue.AddAvailability(day.DayOfWeek, day.OpensAt, day.ClosesAt);

        _context.Venues.Add(venue);
        await _context.SaveChangesAsync(cancellationToken);

        return new CreateVendorVenueResponse(venue.Id);
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return null;

        return await _context.Vendors
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => (Guid?)v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

public sealed class UpdateVendorVenueHandler : IRequestHandler<UpdateVendorVenueCommand>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public UpdateVendorVenueHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task Handle(UpdateVendorVenueCommand request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken);
        if (vendorId == null)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var venue = await _context.Venues
            .Include(v => v.Availability)
            .FirstOrDefaultAsync(v => v.Id == request.VenueId && v.VendorId == vendorId, cancellationToken)
            ?? throw new InvalidOperationException("Venue not found or not owned by this vendor.");

        venue.UpdateDetails(request.Name, request.Description, request.Address);
        venue.UpdateCategory(request.Category);
        venue.UpdateLocation(GeoLocation.Create(request.Latitude, request.Longitude));
        venue.SetMaxCapacity(request.MaxCapacity);

        if (request.OperatingHours != null)
        {
            foreach (var existing in venue.Availability.ToList())
                _context.VenueAvailability.Remove(existing);
            venue.ClearAvailabilityForUpdate();
            foreach (var day in request.OperatingHours)
                venue.AddAvailability(day.DayOfWeek, day.OpensAt, day.ClosesAt);
            foreach (var next in venue.Availability)
                _context.VenueAvailability.Add(next);
        }

        venue.ToggleActive(true);
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return null;

        return await _context.Vendors
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => (Guid?)v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

public sealed class DeactivateVendorVenueHandler : IRequestHandler<DeactivateVendorVenueCommand>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public DeactivateVendorVenueHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task Handle(DeactivateVendorVenueCommand request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken);
        if (vendorId == null)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var venue = await _context.Venues
            .FirstOrDefaultAsync(v => v.Id == request.VenueId && v.VendorId == vendorId, cancellationToken)
            ?? throw new InvalidOperationException("Venue not found or not owned by this vendor.");

        var hasActiveBookings = await _context.ServiceBookings
            .AnyAsync(b => b.VenueId == venue.Id
                && (b.Status == BookingStatus.Pending
                    || b.Status == BookingStatus.Confirmed
                    || b.Status == BookingStatus.CheckedIn), cancellationToken);

        if (hasActiveBookings)
            throw new InvalidOperationException("Cannot deactivate a venue with active bookings. Cancel or complete them first.");

        venue.ToggleActive(false);
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return null;

        return await _context.Vendors
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => (Guid?)v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

public sealed class ListVendorVenuesHandler : IRequestHandler<ListVendorVenuesQuery, IReadOnlyList<VendorVenueResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListVendorVenuesHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<VendorVenueResponse>> Handle(ListVendorVenuesQuery request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken);
        if (vendorId == null)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        return await _context.Venues.AsNoTracking()
            .Include(v => v.Availability)
            .Where(v => v.VendorId == vendorId)
            .OrderBy(v => v.Name)
            .Select(v => new VendorVenueResponse(
                v.Id,
                v.Name,
                v.Category.ToString(),
                v.Description,
                v.Address,
                v.Location.Latitude,
                v.Location.Longitude,
                v.MaxCapacity,
                v.CurrentCapacity,
                v.CheckedInCount,
                v.IsActive,
                v.Availability.OrderBy(a => a.DayOfWeek).Select(a => new OperatingHoursView(
                    a.DayOfWeek,
                    a.OpensAt.ToString("HH:mm", System.Globalization.CultureInfo.InvariantCulture),
                    a.ClosesAt.ToString("HH:mm", System.Globalization.CultureInfo.InvariantCulture))).ToList()))
            .ToListAsync(cancellationToken);
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return null;

        return await _context.Vendors
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => (Guid?)v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

public sealed class ToggleVenueAvailabilityHandler : IRequestHandler<ToggleVenueAvailabilityCommand, ToggleVenueAvailabilityResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ToggleVenueAvailabilityHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<ToggleVenueAvailabilityResponse> Handle(ToggleVenueAvailabilityCommand request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken);
        if (vendorId == null)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var venue = await _context.Venues
            .FirstOrDefaultAsync(v => v.Id == request.VenueId && v.VendorId == vendorId, cancellationToken)
            ?? throw new InvalidOperationException("Venue not found or not owned by this vendor.");

        var desiredState = request.IsActive ?? !venue.IsActive;
        venue.ToggleActive(desiredState);
        await _context.SaveChangesAsync(cancellationToken);

        return new ToggleVenueAvailabilityResponse(venue.IsActive);
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return null;

        return await _context.Vendors
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => (Guid?)v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}
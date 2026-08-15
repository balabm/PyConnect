namespace PondyConnect.Application.Features.Rental;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class CreateScooterRentalHandler : IRequestHandler<CreateScooterRentalCommand, CreateScooterRentalResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateScooterRentalHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<CreateScooterRentalResponse> Handle(CreateScooterRentalCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.Id == request.VendorId && v.IsActive && v.IsApproved, cancellationToken)
            ?? throw new InvalidOperationException("Vendor not found or not approved.");

        var rental = ScooterRental.Create(
            userId: userId,
            vendorId: request.VendorId,
            vehicleName: request.VehicleName,
            rentalStart: request.RentalStart,
            rentalEnd: request.RentalEnd,
            ratePerHour: request.RatePerHour,
            vehiclePlate: request.VehiclePlate,
            notes: request.Notes);

        _context.ScooterRentals.Add(rental);
        await _context.SaveChangesAsync(cancellationToken);

        return new CreateScooterRentalResponse(rental.Id, rental.Status.ToString(), rental.TotalAmount);
    }
}

public sealed class ListUserRentalsHandler : IRequestHandler<ListUserRentalsQuery, IReadOnlyList<ScooterRentalResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListUserRentalsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<ScooterRentalResponse>> Handle(ListUserRentalsQuery request, CancellationToken cancellationToken)
    {
        // Always use the authenticated user's ID; ignore any client-provided UserId.
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");

        var query = _context.ScooterRentals.AsNoTracking().Where(r => r.UserId == userId);
        if (request.Status.HasValue)
            query = query.Where(r => r.Status == request.Status.Value);

        if (_context.IsPostgreSQL)
        {
            return await query
                .Include(r => r.Vendor)
                .OrderByDescending(r => r.CreatedAt)
                .Select(r => new ScooterRentalResponse(
                    r.Id,
                    r.Vendor.Name,
                    r.VehicleName,
                    r.VehiclePlate,
                    r.RentalStart,
                    r.RentalEnd,
                    r.RatePerHour,
                    r.TotalAmount,
                    r.Status.ToString(),
                    r.PaymentStatus.ToString()))
                .ToListAsync(cancellationToken);
        }

        var items = await query
            .Include(r => r.Vendor)
            .ToListAsync(cancellationToken);

        return items
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new ScooterRentalResponse(
                r.Id,
                r.Vendor.Name,
                r.VehicleName,
                r.VehiclePlate,
                r.RentalStart,
                r.RentalEnd,
                r.RatePerHour,
                r.TotalAmount,
                r.Status.ToString(),
                r.PaymentStatus.ToString()))
            .ToList();
    }
}
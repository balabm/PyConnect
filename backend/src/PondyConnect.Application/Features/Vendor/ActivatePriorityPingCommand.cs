namespace PondyConnect.Application.Features.Vendor;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

public sealed record ActivatePriorityPingCommand(Guid VenueId) : IRequest<ActivatePriorityResponse>;

public sealed record ActivatePriorityResponse(
    bool Success,
    decimal RemainingBalance,
    DateTimeOffset Expiry,
    string? Message);

public sealed class ActivatePriorityPingHandler : IRequestHandler<ActivatePriorityPingCommand, ActivatePriorityResponse>
{
    private const decimal PriorityPingCost = 499m;

    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ActivatePriorityPingHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<ActivatePriorityResponse> Handle(ActivatePriorityPingCommand request, CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return new ActivatePriorityResponse(false, 0m, DateTimeOffset.MinValue, "Vendor profile not found.");

        // Use a serializable transaction to prevent concurrent double-spend of credits.
        await using var transaction = await _context.BeginTransactionAsync(cancellationToken);
        try
        {
            if (transaction is null)
            {
                return await ActivateWithoutTransactionAsync(request, cancellationToken);
            }
            // Re-fetch the vendor with locking when transactions are supported.
            var vendor = await _context.Vendors
                .FirstOrDefaultAsync(v => v.ContactPhone == userPhone && v.IsApproved, cancellationToken);

            if (vendor is null)
                return new ActivatePriorityResponse(false, 0m, DateTimeOffset.MinValue, "Vendor profile not found.");

            var venue = await _context.Venues
                .FirstOrDefaultAsync(v => v.Id == request.VenueId && v.VendorId == vendor.Id, cancellationToken);

            if (venue is null)
                return new ActivatePriorityResponse(false, vendor.CreditBalance, DateTimeOffset.MinValue, "Venue not found or not owned by vendor.");

            if (venue.IsPriorityPingActive && venue.PriorityPingExpiry is { } expiry && expiry > DateTimeOffset.UtcNow)
                return new ActivatePriorityResponse(false, vendor.CreditBalance, expiry, "Priority Ping already active.");

            if (vendor.CreditBalance < PriorityPingCost)
                return new ActivatePriorityResponse(false, vendor.CreditBalance, DateTimeOffset.MinValue, "Insufficient credit balance. Please top up.");

            vendor.DeductCredit(PriorityPingCost);
            venue.ActivatePriorityPing();

            await _context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return new ActivatePriorityResponse(true, vendor.CreditBalance, venue.PriorityPingExpiry!.Value, "Priority Ping activated for 7 days.");
        }
        catch
        {
            if (transaction is not null)
                await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    private async Task<ActivatePriorityResponse> ActivateWithoutTransactionAsync(ActivatePriorityPingCommand request, CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            return new ActivatePriorityResponse(false, 0m, DateTimeOffset.MinValue, "Vendor profile not found.");

        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == userPhone && v.IsApproved, cancellationToken);

        if (vendor is null)
            return new ActivatePriorityResponse(false, 0m, DateTimeOffset.MinValue, "Vendor profile not found.");

        var venue = await _context.Venues
            .FirstOrDefaultAsync(v => v.Id == request.VenueId && v.VendorId == vendor.Id, cancellationToken);

        if (venue is null)
            return new ActivatePriorityResponse(false, vendor.CreditBalance, DateTimeOffset.MinValue, "Venue not found or not owned by vendor.");

        if (venue.IsPriorityPingActive && venue.PriorityPingExpiry is { } expiry && expiry > DateTimeOffset.UtcNow)
            return new ActivatePriorityResponse(false, vendor.CreditBalance, expiry, "Priority Ping already active.");

        if (vendor.CreditBalance < PriorityPingCost)
            return new ActivatePriorityResponse(false, vendor.CreditBalance, DateTimeOffset.MinValue, "Insufficient credit balance. Please top up.");

        vendor.DeductCredit(PriorityPingCost);
        venue.ActivatePriorityPing();

        await _context.SaveChangesAsync(cancellationToken);

        return new ActivatePriorityResponse(true, vendor.CreditBalance, venue.PriorityPingExpiry!.Value, "Priority Ping activated for 7 days.");
    }
}

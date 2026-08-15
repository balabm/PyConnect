namespace PondyConnect.Application.Features.Luggage;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class CreateLuggageDropOffHandler : IRequestHandler<CreateLuggageDropOffCommand, CreateLuggageDropOffResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateLuggageDropOffHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<CreateLuggageDropOffResponse> Handle(CreateLuggageDropOffCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.Id == request.VendorId && v.IsActive && v.IsApproved, cancellationToken)
            ?? throw new InvalidOperationException("Vendor not found or not approved.");

        var dropOff = LuggageDropOff.Create(
            userId: userId,
            vendorId: request.VendorId,
            scheduledFor: request.ScheduledFor,
            droppedAt: request.DroppedAt,
            bagCount: request.BagCount,
            ratePerHour: request.RatePerHour,
            notes: request.Notes);

        _context.LuggageDropOffs.Add(dropOff);
        await _context.SaveChangesAsync(cancellationToken);

        return new CreateLuggageDropOffResponse(dropOff.Id, dropOff.Status.ToString(), dropOff.TotalAmount);
    }
}

public sealed class ListUserLuggageHandler : IRequestHandler<ListUserLuggageQuery, IReadOnlyList<LuggageDropOffResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListUserLuggageHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<LuggageDropOffResponse>> Handle(ListUserLuggageQuery request, CancellationToken cancellationToken)
    {
        // Always use the authenticated user's ID; ignore any client-provided UserId.
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");

        var query = _context.LuggageDropOffs.AsNoTracking().Where(l => l.UserId == userId);
        if (request.Status.HasValue)
            query = query.Where(l => l.Status == request.Status.Value);

        if (_context.IsPostgreSQL)
        {
            return await query
                .Include(l => l.Vendor)
                .OrderByDescending(l => l.CreatedAt)
                .Select(l => new LuggageDropOffResponse(
                    l.Id,
                    l.Vendor.Name,
                    l.ScheduledFor,
                    l.DroppedAt,
                    l.BagCount,
                    l.RatePerHour,
                    l.TotalAmount,
                    l.Status.ToString(),
                    l.PaymentStatus.ToString(),
                    l.PickedUpAt))
                .ToListAsync(cancellationToken);
        }

        var items = await query
            .Include(l => l.Vendor)
            .ToListAsync(cancellationToken);

        return items
            .OrderByDescending(l => l.CreatedAt)
            .Select(l => new LuggageDropOffResponse(
                l.Id,
                l.Vendor.Name,
                l.ScheduledFor,
                l.DroppedAt,
                l.BagCount,
                l.RatePerHour,
                l.TotalAmount,
                l.Status.ToString(),
                l.PaymentStatus.ToString(),
                l.PickedUpAt))
            .ToList();
    }
}

public sealed class CancelLuggageDropOffHandler : IRequestHandler<CancelLuggageDropOffCommand, CancelLuggageDropOffResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CancelLuggageDropOffHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<CancelLuggageDropOffResponse> Handle(CancelLuggageDropOffCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var dropOff = await _context.LuggageDropOffs
            .FirstOrDefaultAsync(l => l.Id == request.DropOffId && l.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Luggage drop-off not found.");

        dropOff.Cancel();
        await _context.SaveChangesAsync(cancellationToken);

        return new CancelLuggageDropOffResponse(dropOff.Id, dropOff.Status.ToString());
    }
}

public sealed class GetLuggageDropOffHandler : IRequestHandler<GetLuggageDropOffQuery, LuggageDropOffResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetLuggageDropOffHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<LuggageDropOffResponse> Handle(GetLuggageDropOffQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var dropOff = await _context.LuggageDropOffs
            .AsNoTracking()
            .Include(l => l.Vendor)
            .FirstOrDefaultAsync(l => l.Id == request.Id && l.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Luggage drop-off not found.");

        return new LuggageDropOffResponse(
            dropOff.Id,
            dropOff.Vendor.Name,
            dropOff.ScheduledFor,
            dropOff.DroppedAt,
            dropOff.BagCount,
            dropOff.RatePerHour,
            dropOff.TotalAmount,
            dropOff.Status.ToString(),
            dropOff.PaymentStatus.ToString(),
            dropOff.PickedUpAt);
    }
}

public sealed class ListVendorLuggageHandler : IRequestHandler<ListVendorLuggageQuery, IReadOnlyList<LuggageDropOffResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListVendorLuggageHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<LuggageDropOffResponse>> Handle(ListVendorLuggageQuery request, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone
            ?? throw new UnauthorizedAccessException("Authenticated phone not found.");

        var vendor = await _context.Vendors
            .AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == phone && v.IsApproved, cancellationToken)
            ?? throw new UnauthorizedAccessException("No approved vendor found for the authenticated user.");

        var query = _context.LuggageDropOffs.AsNoTracking().Where(l => l.VendorId == vendor.Id);
        if (request.Status.HasValue)
            query = query.Where(l => l.Status == request.Status.Value);

        return await query
            .Include(l => l.Vendor)
            .OrderByDescending(l => l.DroppedAt)
            .Select(l => new LuggageDropOffResponse(
                l.Id,
                l.Vendor.Name,
                l.ScheduledFor,
                l.DroppedAt,
                l.BagCount,
                l.RatePerHour,
                l.TotalAmount,
                l.Status.ToString(),
                l.PaymentStatus.ToString(),
                l.PickedUpAt))
            .ToListAsync(cancellationToken);
    }
}

public sealed class MarkLuggageCollectedHandler : IRequestHandler<MarkLuggageCollectedCommand, LuggageDropOffResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public MarkLuggageCollectedHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<LuggageDropOffResponse> Handle(MarkLuggageCollectedCommand request, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone
            ?? throw new UnauthorizedAccessException("Authenticated phone not found.");

        var vendor = await _context.Vendors
            .AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == phone && v.IsApproved, cancellationToken)
            ?? throw new UnauthorizedAccessException("No approved vendor found for the authenticated user.");

        var dropOff = await _context.LuggageDropOffs
            .Include(l => l.Vendor)
            .FirstOrDefaultAsync(l => l.Id == request.DropOffId && l.VendorId == vendor.Id, cancellationToken)
            ?? throw new InvalidOperationException("Luggage drop-off not found or not owned by this vendor.");

        dropOff.MarkCollected();
        await _context.SaveChangesAsync(cancellationToken);

        return new LuggageDropOffResponse(
            dropOff.Id,
            dropOff.Vendor.Name,
            dropOff.ScheduledFor,
            dropOff.DroppedAt,
            dropOff.BagCount,
            dropOff.RatePerHour,
            dropOff.TotalAmount,
            dropOff.Status.ToString(),
            dropOff.PaymentStatus.ToString(),
            dropOff.PickedUpAt);
    }
}
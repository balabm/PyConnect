namespace PondyConnect.Application.Features.Vendor;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;

public sealed class CreateVendorPromotionHandler : IRequestHandler<CreateVendorPromotionCommand, CreateVendorPromotionResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateVendorPromotionHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<CreateVendorPromotionResponse> Handle(CreateVendorPromotionCommand request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken);
        if (vendorId == null)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var promotion = PondyConnect.Domain.Entities.VendorPromotion.Create(
            vendorId: vendorId.Value,
            promoType: request.PromoType,
            title: request.Title,
            cost: request.Cost,
            startsAt: request.StartsAt,
            expiresAt: request.ExpiresAt,
            description: request.Description,
            targetLatitude: request.TargetLatitude,
            targetLongitude: request.TargetLongitude,
            targetRadiusKm: request.TargetRadiusKm);

        _context.VendorPromotions.Add(promotion);
        await _context.SaveChangesAsync(cancellationToken);

        return new CreateVendorPromotionResponse(promotion.Id, promotion.IsValidAt(DateTimeOffset.UtcNow) ? "Live" : "Scheduled");
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

public sealed class ListVendorPromotionsHandler : IRequestHandler<ListVendorPromotionsQuery, IReadOnlyList<VendorPromotionResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListVendorPromotionsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<VendorPromotionResponse>> Handle(ListVendorPromotionsQuery request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken);
        if (vendorId == null)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var query = _context.VendorPromotions.AsNoTracking()
            .Where(p => p.VendorId == vendorId);

        if (_context.IsPostgreSQL)
        {
            return await query
                .OrderByDescending(p => p.CreatedAt)
                .Select(p => new VendorPromotionResponse(
                    p.Id,
                    p.PromoType.ToString(),
                    p.Title,
                    p.Description,
                    p.Cost,
                    p.StartsAt,
                    p.ExpiresAt,
                    p.IsActive,
                    p.TargetRadiusKm))
                .ToListAsync(cancellationToken);
        }

        var items = await query.ToListAsync(cancellationToken);

        return items
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => new VendorPromotionResponse(
                p.Id,
                p.PromoType.ToString(),
                p.Title,
                p.Description,
                p.Cost,
                p.StartsAt,
                p.ExpiresAt,
                p.IsActive,
                p.TargetRadiusKm))
            .ToList();
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
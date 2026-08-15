namespace PondyConnect.Application.Features.Vendor;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed record CreateFlashPromoCommand(
    decimal DiscountPercentage,
    int DurationMinutes,
    string? Title = null,
    string? Description = null) : IRequest<FlashPromoResponse>;

public sealed record FlashPromoResponse(
    Guid Id,
    Guid VendorId,
    string Title,
    decimal DiscountPercentage,
    DateTimeOffset StartsAt,
    DateTimeOffset ExpiresAt,
    bool IsActive);

public sealed class CreateFlashPromoValidator : AbstractValidator<CreateFlashPromoCommand>
{
    public CreateFlashPromoValidator()
    {
        RuleFor(x => x.DiscountPercentage).InclusiveBetween(1, 100);
        RuleFor(x => x.DurationMinutes).InclusiveBetween(5, 1440);
    }
}

public sealed class CreateFlashPromoHandler : IRequestHandler<CreateFlashPromoCommand, FlashPromoResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateFlashPromoHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<FlashPromoResponse> Handle(CreateFlashPromoCommand request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken)
            ?? throw new UnauthorizedAccessException("Vendor profile not found.");

        var now = DateTimeOffset.UtcNow;
        var title = request.Title ?? $"Flash Sale {request.DiscountPercentage}% Off";

        var promo = VendorPromotion.Create(
            vendorId: vendorId,
            promoType: PromoType.FlashSale,
            title: title,
            cost: 0m,
            startsAt: now,
            expiresAt: now.AddMinutes(request.DurationMinutes),
            description: request.Description,
            discountPercentage: request.DiscountPercentage);

        _context.VendorPromotions.Add(promo);
        await _context.SaveChangesAsync(cancellationToken);

        return new FlashPromoResponse(promo.Id, promo.VendorId, promo.Title, promo.DiscountPercentage ?? 0, promo.StartsAt, promo.ExpiresAt, promo.IsActive);
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone)) return null;

        return await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

public sealed record ListActiveFlashPromosQuery(double? Latitude = null, double? Longitude = null) : IRequest<IReadOnlyList<FlashPromoResponse>>;

public sealed class ListActiveFlashPromosHandler : IRequestHandler<ListActiveFlashPromosQuery, IReadOnlyList<FlashPromoResponse>>
{
    private readonly IApplicationDbContext _context;

    public ListActiveFlashPromosHandler(IApplicationDbContext context) => _context = context;

    public async Task<IReadOnlyList<FlashPromoResponse>> Handle(ListActiveFlashPromosQuery request, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;

        var promos = await _context.VendorPromotions.AsNoTracking()
            .Where(p => p.PromoType == PromoType.FlashSale && p.IsActive)
            .ToListAsync(cancellationToken);

        return promos
            .Where(p => p.IsValidAt(now))
            .Select(p => new FlashPromoResponse(p.Id, p.VendorId, p.Title, p.DiscountPercentage ?? 0, p.StartsAt, p.ExpiresAt, p.IsActive))
            .ToList();
    }
}

public sealed record ListVendorFlashPromosQuery() : IRequest<IReadOnlyList<FlashPromoResponse>>;

public sealed class ListVendorFlashPromosHandler : IRequestHandler<ListVendorFlashPromosQuery, IReadOnlyList<FlashPromoResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListVendorFlashPromosHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<FlashPromoResponse>> Handle(ListVendorFlashPromosQuery request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken)
            ?? throw new UnauthorizedAccessException("Vendor profile not found.");

        var promos = await _context.VendorPromotions.AsNoTracking()
            .Where(p => p.VendorId == vendorId && p.PromoType == PromoType.FlashSale)
            .ToListAsync(cancellationToken);

        return promos
            .OrderByDescending(p => p.StartsAt)
            .Select(p => new FlashPromoResponse(p.Id, p.VendorId, p.Title, p.DiscountPercentage ?? 0, p.StartsAt, p.ExpiresAt, p.IsActive))
            .ToList();
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone)) return null;

        return await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

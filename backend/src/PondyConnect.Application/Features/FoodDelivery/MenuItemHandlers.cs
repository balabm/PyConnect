namespace PondyConnect.Application.Features.FoodDelivery;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

public sealed record CreateMenuItemCommand(
    string? Phone,
    string Name,
    decimal Price,
    string Category,
    Guid? VenueId = null,
    string? Description = null,
    string? ImageUrl = null,
    bool IsLateNight = false) : IRequest<MenuItemResponse>;

public sealed record MenuItemResponse(
    Guid Id,
    Guid VendorId,
    string Name,
    string? Description,
    decimal Price,
    string Category,
    bool IsAvailable,
    bool IsLateNight,
    string? ImageUrl,
    IReadOnlyList<ModifierGroupResponse>? ModifierGroups = null);

public sealed record ModifierGroupResponse(
    Guid Id,
    Guid MenuItemId,
    string Name,
    int MinSelections,
    int MaxSelections,
    int SortOrder,
    bool IsRequired,
    IReadOnlyList<ModifierResponse> Modifiers);

public sealed record ModifierResponse(
    Guid Id,
    Guid ModifierGroupId,
    string Name,
    decimal Price,
    bool IsAvailable,
    int SortOrder);

public sealed class CreateMenuItemValidator : AbstractValidator<CreateMenuItemCommand>
{
    public CreateMenuItemValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Price).GreaterThan(0);
        RuleFor(x => x.Category).NotEmpty().MaximumLength(50);
    }
}

public sealed class CreateMenuItemHandler : IRequestHandler<CreateMenuItemCommand, MenuItemResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateMenuItemHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<MenuItemResponse> Handle(CreateMenuItemCommand request, CancellationToken cancellationToken)
    {
        var phone = request.Phone ?? _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var vendorId = await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == phone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (vendorId == Guid.Empty)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var item = MenuItem.Create(
            vendorId: vendorId,
            name: request.Name,
            price: request.Price,
            category: request.Category,
            venueId: request.VenueId,
            description: request.Description,
            imageUrl: request.ImageUrl,
            isLateNight: request.IsLateNight);

        _context.MenuItems.Add(item);
        await _context.SaveChangesAsync(cancellationToken);

        return new MenuItemResponse(item.Id, item.VendorId, item.Name, item.Description, item.Price, item.Category, item.IsAvailable, item.IsLateNight, item.ImageUrl, []);
    }
}

public sealed record UpdateMenuItemCommand(
    Guid MenuItemId,
    string Name,
    string? Description,
    string Category,
    decimal? NewPrice) : IRequest<Unit>;

public sealed class UpdateMenuItemHandler : IRequestHandler<UpdateMenuItemCommand, Unit>
{
    private readonly IApplicationDbContext _context;

    public UpdateMenuItemHandler(IApplicationDbContext context) => _context = context;

    public async Task<Unit> Handle(UpdateMenuItemCommand request, CancellationToken cancellationToken)
    {
        var item = await _context.MenuItems.FirstOrDefaultAsync(m => m.Id == request.MenuItemId, cancellationToken)
            ?? throw new InvalidOperationException("Menu item not found.");

        if (request.NewPrice.HasValue)
            item.UpdatePrice(request.NewPrice.Value);
        item.UpdateDetails(request.Name, request.Description, request.Category);

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed record ToggleMenuItemCommand(Guid MenuItemId) : IRequest<Unit>;

public sealed class ToggleMenuItemHandler : IRequestHandler<ToggleMenuItemCommand, Unit>
{
    private readonly IApplicationDbContext _context;

    public ToggleMenuItemHandler(IApplicationDbContext context) => _context = context;

    public async Task<Unit> Handle(ToggleMenuItemCommand request, CancellationToken cancellationToken)
    {
        var item = await _context.MenuItems.FirstOrDefaultAsync(m => m.Id == request.MenuItemId, cancellationToken)
            ?? throw new InvalidOperationException("Menu item not found.");

        item.ToggleAvailability();
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed record ListMenuItemsQuery(Guid VendorId, bool OnlyAvailable = true) : IRequest<IReadOnlyList<MenuItemResponse>>;

public sealed class ListMenuItemsHandler : IRequestHandler<ListMenuItemsQuery, IReadOnlyList<MenuItemResponse>>
{
    private readonly IApplicationDbContext _context;

    public ListMenuItemsHandler(IApplicationDbContext context) => _context = context;

    public async Task<IReadOnlyList<MenuItemResponse>> Handle(ListMenuItemsQuery request, CancellationToken cancellationToken)
    {
        var query = _context.MenuItems.AsNoTracking().Where(m => m.VendorId == request.VendorId);
        if (request.OnlyAvailable)
            query = query.Where(m => m.IsAvailable);

        var items = await query
            .OrderBy(m => m.Category).ThenBy(m => m.Name)
            .Include(m => m.ModifierGroups.OrderBy(g => g.SortOrder))
                .ThenInclude(g => g.Modifiers.OrderBy(mod => mod.SortOrder))
            .ToListAsync(cancellationToken);
        return items.Select(MenuItemMapper.MapMenuItemResponse).ToList();
    }
}

public sealed record ListVendorMenuItemsQuery() : IRequest<IReadOnlyList<MenuItemResponse>>;

public sealed class ListVendorMenuItemsHandler : IRequestHandler<ListVendorMenuItemsQuery, IReadOnlyList<MenuItemResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListVendorMenuItemsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<MenuItemResponse>> Handle(ListVendorMenuItemsQuery request, CancellationToken cancellationToken)
    {
        var userPhone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(userPhone))
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var vendorId = await _context.Vendors.AsNoTracking()
            .Where(v => v.ContactPhone == userPhone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (vendorId == Guid.Empty)
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var items = await _context.MenuItems.AsNoTracking()
            .Where(m => m.VendorId == vendorId)
            .OrderBy(m => m.Category).ThenBy(m => m.Name)
            .Include(m => m.ModifierGroups.OrderBy(g => g.SortOrder))
                .ThenInclude(g => g.Modifiers.OrderBy(mod => mod.SortOrder))
            .ToListAsync(cancellationToken);

        return items.Select(MenuItemMapper.MapMenuItemResponse).ToList();
    }
}

public sealed record DeleteMenuItemCommand(Guid MenuItemId) : IRequest<Unit>;

public sealed class DeleteMenuItemHandler : IRequestHandler<DeleteMenuItemCommand, Unit>
{
    private readonly IApplicationDbContext _context;

    public DeleteMenuItemHandler(IApplicationDbContext context) => _context = context;

    public async Task<Unit> Handle(DeleteMenuItemCommand request, CancellationToken cancellationToken)
    {
        var item = await _context.MenuItems.FirstOrDefaultAsync(m => m.Id == request.MenuItemId, cancellationToken)
            ?? throw new InvalidOperationException("Menu item not found.");

        _context.MenuItems.Remove(item);
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

/// <summary>
/// Maps a <see cref="MenuItem"/> entity (with loaded modifier groups) to a
/// <see cref="MenuItemResponse"/> DTO including the full modifier tree.
/// </summary>
internal static class MenuItemMapper
{
    public static MenuItemResponse MapMenuItemResponse(MenuItem m)
    {
        var groups = m.ModifierGroups
            .OrderBy(g => g.SortOrder)
            .Select(g => new ModifierGroupResponse(
                g.Id,
                g.MenuItemId,
                g.Name,
                g.MinSelections,
                g.MaxSelections,
                g.SortOrder,
                g.IsRequired,
                g.Modifiers
                    .OrderBy(mod => mod.SortOrder)
                    .Select(mod => new ModifierResponse(
                        mod.Id,
                        mod.ModifierGroupId,
                        mod.Name,
                        mod.Price,
                        mod.IsAvailable,
                        mod.SortOrder))
                    .ToList()))
            .ToList();

        return new MenuItemResponse(
            m.Id,
            m.VendorId,
            m.Name,
            m.Description,
            m.Price,
            m.Category,
            m.IsAvailable,
            m.IsLateNight,
            m.ImageUrl,
            groups);
    }
}

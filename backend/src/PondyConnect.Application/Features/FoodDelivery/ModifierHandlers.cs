namespace PondyConnect.Application.Features.FoodDelivery;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

// ─────────────────────────────────────────────────────────────────────────────
// Create Modifier Group
// ─────────────────────────────────────────────────────────────────────────────

public sealed record CreateModifierGroupCommand(
    Guid MenuItemId,
    string Name,
    int MinSelections = 0,
    int MaxSelections = 0,
    int SortOrder = 0) : IRequest<ModifierGroupResponse>;

public sealed class CreateModifierGroupValidator : AbstractValidator<CreateModifierGroupCommand>
{
    public CreateModifierGroupValidator()
    {
        RuleFor(x => x.MenuItemId).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.MinSelections).GreaterThanOrEqualTo(0);
        RuleFor(x => x.MaxSelections).GreaterThanOrEqualTo(0);
    }
}

public sealed class CreateModifierGroupHandler : IRequestHandler<CreateModifierGroupCommand, ModifierGroupResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateModifierGroupHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<ModifierGroupResponse> Handle(CreateModifierGroupCommand request, CancellationToken cancellationToken)
    {
        var menuItem = await _context.MenuItems
            .FirstOrDefaultAsync(m => m.Id == request.MenuItemId, cancellationToken)
            ?? throw new InvalidOperationException("Menu item not found.");

        await EnsureVendorOwnershipAsync(menuItem.VendorId, cancellationToken);

        var group = ModifierGroup.Create(
            request.MenuItemId,
            request.Name,
            request.MinSelections,
            request.MaxSelections,
            request.SortOrder);

        _context.ModifierGroups.Add(group);
        await _context.SaveChangesAsync(cancellationToken);

        return new ModifierGroupResponse(
            group.Id,
            group.MenuItemId,
            group.Name,
            group.MinSelections,
            group.MaxSelections,
            group.SortOrder,
            group.IsRequired,
            []);
    }

    private async Task EnsureVendorOwnershipAsync(Guid vendorId, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var ownsVendor = await _context.Vendors.AsNoTracking()
            .AnyAsync(v => v.Id == vendorId && v.ContactPhone == phone && v.IsApproved, cancellationToken);

        if (!ownsVendor)
            throw new UnauthorizedAccessException("You do not own this menu item.");
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Modifier (add to a group)
// ─────────────────────────────────────────────────────────────────────────────

public sealed record CreateModifierCommand(
    Guid ModifierGroupId,
    string Name,
    decimal Price = 0m,
    bool IsAvailable = true,
    int SortOrder = 0) : IRequest<ModifierResponse>;

public sealed class CreateModifierValidator : AbstractValidator<CreateModifierCommand>
{
    public CreateModifierValidator()
    {
        RuleFor(x => x.ModifierGroupId).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Price).GreaterThanOrEqualTo(0);
    }
}

public sealed class CreateModifierHandler : IRequestHandler<CreateModifierCommand, ModifierResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateModifierHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<ModifierResponse> Handle(CreateModifierCommand request, CancellationToken cancellationToken)
    {
        var group = await _context.ModifierGroups
            .Include(g => g.MenuItem)
            .FirstOrDefaultAsync(g => g.Id == request.ModifierGroupId, cancellationToken)
            ?? throw new InvalidOperationException("Modifier group not found.");

        await EnsureVendorOwnershipAsync(group.MenuItem!.VendorId, cancellationToken);

        var modifier = Modifier.Create(
            request.ModifierGroupId,
            request.Name,
            request.Price,
            request.IsAvailable,
            request.SortOrder);

        _context.Modifiers.Add(modifier);
        await _context.SaveChangesAsync(cancellationToken);

        return new ModifierResponse(
            modifier.Id,
            modifier.ModifierGroupId,
            modifier.Name,
            modifier.Price,
            modifier.IsAvailable,
            modifier.SortOrder);
    }

    private async Task EnsureVendorOwnershipAsync(Guid vendorId, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var ownsVendor = await _context.Vendors.AsNoTracking()
            .AnyAsync(v => v.Id == vendorId && v.ContactPhone == phone && v.IsApproved, cancellationToken);

        if (!ownsVendor)
            throw new UnauthorizedAccessException("You do not own this menu item.");
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Update Modifier
// ─────────────────────────────────────────────────────────────────────────────

public sealed record UpdateModifierCommand(
    Guid ModifierId,
    string Name,
    decimal Price,
    bool IsAvailable) : IRequest<Unit>;

public sealed class UpdateModifierValidator : AbstractValidator<UpdateModifierCommand>
{
    public UpdateModifierValidator()
    {
        RuleFor(x => x.ModifierId).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Price).GreaterThanOrEqualTo(0);
    }
}

public sealed class UpdateModifierHandler : IRequestHandler<UpdateModifierCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public UpdateModifierHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(UpdateModifierCommand request, CancellationToken cancellationToken)
    {
        var modifier = await _context.Modifiers
            .Include(m => m.ModifierGroup!)
                .ThenInclude(g => g.MenuItem)
            .FirstOrDefaultAsync(m => m.Id == request.ModifierId, cancellationToken)
            ?? throw new InvalidOperationException("Modifier not found.");

        await EnsureVendorOwnershipAsync(modifier.ModifierGroup!.MenuItem!.VendorId, cancellationToken);

        modifier.Update(request.Name, request.Price, request.IsAvailable);
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }

    private async Task EnsureVendorOwnershipAsync(Guid vendorId, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var ownsVendor = await _context.Vendors.AsNoTracking()
            .AnyAsync(v => v.Id == vendorId && v.ContactPhone == phone && v.IsApproved, cancellationToken);

        if (!ownsVendor)
            throw new UnauthorizedAccessException("You do not own this menu item.");
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete Modifier
// ─────────────────────────────────────────────────────────────────────────────

public sealed record DeleteModifierCommand(Guid ModifierId) : IRequest<Unit>;

public sealed class DeleteModifierHandler : IRequestHandler<DeleteModifierCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public DeleteModifierHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(DeleteModifierCommand request, CancellationToken cancellationToken)
    {
        var modifier = await _context.Modifiers
            .Include(m => m.ModifierGroup!)
                .ThenInclude(g => g.MenuItem)
            .FirstOrDefaultAsync(m => m.Id == request.ModifierId, cancellationToken)
            ?? throw new InvalidOperationException("Modifier not found.");

        await EnsureVendorOwnershipAsync(modifier.ModifierGroup!.MenuItem!.VendorId, cancellationToken);

        _context.Modifiers.Remove(modifier);
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }

    private async Task EnsureVendorOwnershipAsync(Guid vendorId, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            throw new UnauthorizedAccessException("Vendor profile not found.");

        var ownsVendor = await _context.Vendors.AsNoTracking()
            .AnyAsync(v => v.Id == vendorId && v.ContactPhone == phone && v.IsApproved, cancellationToken);

        if (!ownsVendor)
            throw new UnauthorizedAccessException("You do not own this menu item.");
    }
}

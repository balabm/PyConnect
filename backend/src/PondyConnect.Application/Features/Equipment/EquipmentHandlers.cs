namespace PondyConnect.Application.Features.Equipment;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

// ── Equipment Item CRUD (Vendor) ──

public sealed record CreateEquipmentItemCommand(
    string Name,
    decimal DailyRentalPrice,
    decimal SecurityDepositAmount,
    int TotalUnits,
    string Category = "Misc",
    string? Description = null,
    string? ImageUrl = null) : IRequest<EquipmentItemDto>;

public sealed record EquipmentItemDto(
    Guid Id,
    string Name,
    string? Description,
    decimal DailyRentalPrice,
    decimal SecurityDepositAmount,
    int TotalUnits,
    int AvailableUnits,
    string Category,
    string? ImageUrl,
    bool IsAvailable);

public sealed class CreateEquipmentItemHandler : IRequestHandler<CreateEquipmentItemCommand, EquipmentItemDto>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateEquipmentItemHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<EquipmentItemDto> Handle(CreateEquipmentItemCommand request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken)
            ?? throw new UnauthorizedAccessException("Vendor not found for current user.");

        var item = EquipmentItem.Create(
            vendorId,
            request.Name,
            request.DailyRentalPrice,
            request.SecurityDepositAmount,
            request.TotalUnits,
            request.Category,
            request.Description,
            request.ImageUrl);

        _context.EquipmentItems.Add(item);
        await _context.SaveChangesAsync(cancellationToken);

        return ToDto(item);
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return null;
        return await _context.Vendors
            .Where(v => v.ContactPhone == phone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }

    internal static EquipmentItemDto ToDto(EquipmentItem e) => new(
        e.Id, e.Name, e.Description, e.DailyRentalPrice,
        e.SecurityDepositAmount, e.TotalUnits, e.AvailableUnits,
        e.Category, e.ImageUrl, e.IsAvailable);
}

public sealed record UpdateEquipmentItemCommand(
    Guid Id,
    decimal? DailyRentalPrice,
    decimal? SecurityDepositAmount,
    int? StockAdjustment) : IRequest<EquipmentItemDto>;

public sealed class UpdateEquipmentItemHandler : IRequestHandler<UpdateEquipmentItemCommand, EquipmentItemDto>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public UpdateEquipmentItemHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<EquipmentItemDto> Handle(UpdateEquipmentItemCommand request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken)
            ?? throw new UnauthorizedAccessException("Vendor not found.");

        var item = await _context.EquipmentItems
            .FirstOrDefaultAsync(e => e.Id == request.Id && e.VendorId == vendorId, cancellationToken)
            ?? throw new UnauthorizedAccessException("Equipment item not found or not owned by vendor.");

        if (request.DailyRentalPrice.HasValue && request.SecurityDepositAmount.HasValue)
            item.UpdatePricing(request.DailyRentalPrice.Value, request.SecurityDepositAmount.Value);

        if (request.StockAdjustment.HasValue && request.StockAdjustment.Value != 0)
            item.AdjustStock(request.StockAdjustment.Value);

        await _context.SaveChangesAsync(cancellationToken);
        return CreateEquipmentItemHandler.ToDto(item);
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return null;
        return await _context.Vendors
            .Where(v => v.ContactPhone == phone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

public sealed record ListEquipmentItemsQuery() : IRequest<IReadOnlyList<EquipmentItemDto>>;

public sealed class ListEquipmentItemsHandler : IRequestHandler<ListEquipmentItemsQuery, IReadOnlyList<EquipmentItemDto>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListEquipmentItemsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<EquipmentItemDto>> Handle(ListEquipmentItemsQuery request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken)
            ?? throw new UnauthorizedAccessException("Vendor not found.");

        var items = await _context.EquipmentItems
            .AsNoTracking()
            .Where(e => e.VendorId == vendorId)
            .OrderBy(e => e.Name)
            .ToListAsync(cancellationToken);

        return items.Select(CreateEquipmentItemHandler.ToDto).ToList();
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return null;
        return await _context.Vendors
            .Where(v => v.ContactPhone == phone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

// ── Equipment Browse (Consumer) ──

public sealed record BrowseEquipmentQuery(string? Category = null) : IRequest<IReadOnlyList<EquipmentItemDto>>;

public sealed class BrowseEquipmentHandler : IRequestHandler<BrowseEquipmentQuery, IReadOnlyList<EquipmentItemDto>>
{
    private readonly IApplicationDbContext _context;

    public BrowseEquipmentHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<EquipmentItemDto>> Handle(BrowseEquipmentQuery request, CancellationToken cancellationToken)
    {
        var query = _context.EquipmentItems.AsNoTracking().Where(e => e.IsAvailable);

        if (!string.IsNullOrWhiteSpace(request.Category))
            query = query.Where(e => e.Category == request.Category);

        var items = await query.OrderBy(e => e.DailyRentalPrice).ToListAsync(cancellationToken);
        return items.Select(CreateEquipmentItemHandler.ToDto).ToList();
    }
}

// ── Equipment Rental Lifecycle ──

public sealed record CreateEquipmentRentalCommand(
    Guid EquipmentItemId,
    int UnitsBooked,
    DateTimeOffset RentalStart,
    DateTimeOffset RentalEnd,
    string? DeliveryAddress = null,
    string? Notes = null) : IRequest<CreateEquipmentRentalResult>;

public sealed record CreateEquipmentRentalResult(
    Guid RentalId,
    decimal TotalAmount,
    decimal SecurityDeposit,
    string? RazorpayOrderId);

public sealed class CreateEquipmentRentalHandler : IRequestHandler<CreateEquipmentRentalCommand, CreateEquipmentRentalResult>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IPaymentGateway _paymentGateway;

    public CreateEquipmentRentalHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IPaymentGateway paymentGateway)
    {
        _context = context;
        _currentUser = currentUser;
        _paymentGateway = paymentGateway;
    }

    public async Task<CreateEquipmentRentalResult> Handle(CreateEquipmentRentalCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var item = await _context.EquipmentItems
            .FirstOrDefaultAsync(e => e.Id == request.EquipmentItemId && e.IsAvailable, cancellationToken)
            ?? throw new InvalidOperationException("Equipment item not available.");

        if (request.UnitsBooked > item.AvailableUnits)
            throw new InvalidOperationException("Not enough units available.");

        var rental = EquipmentRental.Create(
            userId,
            item.VendorId,
            item.Id,
            request.UnitsBooked,
            request.RentalStart,
            request.RentalEnd,
            item.DailyRentalPrice,
            item.SecurityDepositAmount,
            request.DeliveryAddress,
            request.Notes);

        // Reserve units immediately
        item.ReserveUnits(request.UnitsBooked);

        _context.EquipmentRentals.Add(rental);

        // Create Razorpay order for the rental amount (auto-capture)
        var receipt = $"equip-{rental.Id.ToString().Substring(0, 8)}";
        var order = await _paymentGateway.CreateOrderAsync(
            rental.TotalAmount, "INR", receipt, capture: true, cancellationToken: cancellationToken);

        if (!order.Success || order.OrderId is null)
            throw new InvalidOperationException(order.ErrorMessage ?? "Failed to create payment order.");

        await _context.SaveChangesAsync(cancellationToken);

        return new CreateEquipmentRentalResult(rental.Id, rental.TotalAmount, rental.SecurityDeposit, order.OrderId);
    }
}

public sealed record ConfirmEquipmentRentalCommand(
    Guid RentalId,
    string RazorpayOrderId,
    string RazorpayPaymentId,
    string Signature) : IRequest<Unit>;

public sealed class ConfirmEquipmentRentalHandler : IRequestHandler<ConfirmEquipmentRentalCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IPaymentGateway _paymentGateway;

    public ConfirmEquipmentRentalHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IPaymentGateway paymentGateway)
    {
        _context = context;
        _currentUser = currentUser;
        _paymentGateway = paymentGateway;
    }

    public async Task<Unit> Handle(ConfirmEquipmentRentalCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var rental = await _context.EquipmentRentals
            .FirstOrDefaultAsync(r => r.Id == request.RentalId && r.UserId == userId, cancellationToken)
            ?? throw new UnauthorizedAccessException("Rental not found or not owned by user.");

        var valid = await _paymentGateway.VerifyPaymentSignatureAsync(
            request.RazorpayOrderId, request.RazorpayPaymentId, request.Signature, cancellationToken);

        if (!valid)
            throw new InvalidOperationException("Invalid payment signature.");

        rental.RecordPayment(PaymentStatus.Captured, request.RazorpayPaymentId);

        // Create auth-hold order for the security deposit (capture: false)
        if (rental.SecurityDeposit > 0)
        {
            var depositReceipt = $"deposit-{rental.Id.ToString().Substring(0, 8)}";
            var depositOrder = await _paymentGateway.CreateOrderAsync(
                rental.SecurityDeposit, "INR", depositReceipt, capture: false, cancellationToken: cancellationToken);

            if (depositOrder.Success && depositOrder.OrderId is not null)
            {
                // The deposit payment ID will be recorded after the user completes
                // the auth-hold checkout. For now, record the order reference.
                rental.RecordDeposit(depositOrder.OrderId);
            }
        }

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

// ── Vendor Rental Management (Kanban) ──

public sealed record ListEquipmentRentalsQuery(string? StatusFilter = null) : IRequest<IReadOnlyList<EquipmentRentalDto>>;

public sealed record EquipmentRentalDto(
    Guid Id,
    string ItemName,
    int UnitsBooked,
    DateTimeOffset RentalStart,
    DateTimeOffset RentalEnd,
    decimal TotalAmount,
    decimal SecurityDeposit,
    string Status,
    string PaymentStatus,
    string? DeliveryAddress,
    string? Notes);

public sealed class ListEquipmentRentalsHandler : IRequestHandler<ListEquipmentRentalsQuery, IReadOnlyList<EquipmentRentalDto>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListEquipmentRentalsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<EquipmentRentalDto>> Handle(ListEquipmentRentalsQuery request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken)
            ?? throw new UnauthorizedAccessException("Vendor not found.");

        var query = _context.EquipmentRentals.AsNoTracking().Where(r => r.VendorId == vendorId);

        if (!string.IsNullOrWhiteSpace(request.StatusFilter) &&
            Enum.TryParse<EquipmentRentalStatus>(request.StatusFilter, true, out var statusFilter))
        {
            query = query.Where(r => r.Status == statusFilter);
        }

        var rentals = await query
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new EquipmentRentalDto(
                r.Id,
                _context.EquipmentItems.Where(e => e.Id == r.EquipmentItemId).Select(e => e.Name).FirstOrDefault() ?? "",
                r.UnitsBooked,
                r.RentalStart,
                r.RentalEnd,
                r.TotalAmount,
                r.SecurityDeposit,
                r.Status.ToString(),
                r.PaymentStatus.ToString(),
                r.DeliveryAddress,
                r.Notes))
            .ToListAsync(cancellationToken);

        return rentals;
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return null;
        return await _context.Vendors
            .Where(v => v.ContactPhone == phone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

public sealed record UpdateEquipmentRentalStatusCommand(
    Guid RentalId,
    string NewStatus) : IRequest<Unit>;

public sealed class UpdateEquipmentRentalStatusHandler : IRequestHandler<UpdateEquipmentRentalStatusCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public UpdateEquipmentRentalStatusHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(UpdateEquipmentRentalStatusCommand request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken)
            ?? throw new UnauthorizedAccessException("Vendor not found.");

        var rental = await _context.EquipmentRentals
            .FirstOrDefaultAsync(r => r.Id == request.RentalId && r.VendorId == vendorId, cancellationToken)
            ?? throw new UnauthorizedAccessException("Rental not found or not owned by vendor.");

        if (!Enum.TryParse<EquipmentRentalStatus>(request.NewStatus, true, out var newStatus))
            throw new ArgumentException($"Invalid status: {request.NewStatus}");

        switch (newStatus)
        {
            case EquipmentRentalStatus.Delivered:
                rental.MarkDelivered();
                break;
            case EquipmentRentalStatus.ActiveInField:
                rental.MarkActiveInField();
                break;
            case EquipmentRentalStatus.AwaitingReturn:
                rental.MarkAwaitingReturn();
                break;
            case EquipmentRentalStatus.Cancelled:
                rental.Cancel();
                // Restore reserved units
                var item = await _context.EquipmentItems.FirstOrDefaultAsync(e => e.Id == rental.EquipmentItemId, cancellationToken);
                item?.RestoreUnits(rental.UnitsBooked);
                break;
            default:
                throw new ArgumentException($"Cannot directly set status to {request.NewStatus}. Use the return endpoint for returns.");
        }

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return null;
        return await _context.Vendors
            .Where(v => v.ContactPhone == phone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

public sealed record CompleteEquipmentReturnCommand(
    Guid RentalId,
    int LateMinutes = 0,
    decimal DamageAmount = 0m,
    string? ReturnConditionPhotosJson = null) : IRequest<CompleteEquipmentReturnResult>;

public sealed record CompleteEquipmentReturnResult(
    decimal DepositPenalty,
    decimal DepositRefunded);

public sealed class CompleteEquipmentReturnHandler : IRequestHandler<CompleteEquipmentReturnCommand, CompleteEquipmentReturnResult>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IPaymentGateway _paymentGateway;

    public CompleteEquipmentReturnHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IPaymentGateway paymentGateway)
    {
        _context = context;
        _currentUser = currentUser;
        _paymentGateway = paymentGateway;
    }

    public async Task<CompleteEquipmentReturnResult> Handle(CompleteEquipmentReturnCommand request, CancellationToken cancellationToken)
    {
        var vendorId = await ResolveVendorIdAsync(cancellationToken)
            ?? throw new UnauthorizedAccessException("Vendor not found.");

        var rental = await _context.EquipmentRentals
            .FirstOrDefaultAsync(r => r.Id == request.RentalId && r.VendorId == vendorId, cancellationToken)
            ?? throw new UnauthorizedAccessException("Rental not found or not owned by vendor.");

        rental.CompleteReturn(request.LateMinutes, request.DamageAmount, request.ReturnConditionPhotosJson);

        // Restore available units
        var item = await _context.EquipmentItems.FirstOrDefaultAsync(e => e.Id == rental.EquipmentItemId, cancellationToken);
        item?.RestoreUnits(rental.UnitsBooked);

        // Handle deposit capture/release via payment gateway
        if (!string.IsNullOrWhiteSpace(rental.DepositPaymentReference))
        {
            if (rental.DepositPenalty > 0)
            {
                // Capture the penalty amount from the auth-hold
                _ = await _paymentGateway.CapturePaymentAsync(
                    rental.DepositPaymentReference, rental.DepositPenalty, cancellationToken);

                // Release the remainder if any
                if (rental.DepositRefunded > 0)
                {
                    _ = await _paymentGateway.ReleasePaymentAsync(
                        rental.DepositPaymentReference, cancellationToken);
                }
            }
            else
            {
                // No damage — release the full auth-hold
                _ = await _paymentGateway.ReleasePaymentAsync(
                    rental.DepositPaymentReference, cancellationToken);
            }
        }

        await _context.SaveChangesAsync(cancellationToken);

        return new CompleteEquipmentReturnResult(rental.DepositPenalty, rental.DepositRefunded);
    }

    private async Task<Guid?> ResolveVendorIdAsync(CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            return null;
        return await _context.Vendors
            .Where(v => v.ContactPhone == phone && v.IsApproved)
            .Select(v => v.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

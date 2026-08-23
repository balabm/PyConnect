namespace PondyConnect.Application.Features.Vendor;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Issues a fresh OTP for a vendor owner phone number. Reuses the same
/// OTP infrastructure as the consumer auth flow.
/// </summary>
public sealed record RequestVendorOtpCommand(string Phone) : IRequest<VendorOtpRequestedResponse>;

public sealed class RequestVendorOtpCommandValidator : AbstractValidator<RequestVendorOtpCommand>
{
    public RequestVendorOtpCommandValidator()
    {
        RuleFor(x => x.Phone)
            .NotEmpty()
            .Matches("^[0-9]{10,15}$")
            .WithMessage("A valid 10+ digit phone number is required.");
    }
}

public sealed record VendorOtpRequestedResponse(string Phone, int OtpExpirySeconds);

/// <summary>
/// Exchanges a verified OTP for a vendor-scoped JWT. The phone number must
/// resolve to a registered vendor. Pending or rejected vendors receive a
/// limited token so they can view their approval status.
/// </summary>
public sealed record VerifyVendorOtpCommand(
    string Phone,
    string OtpCode,
    string? OwnerName = null) : IRequest<VendorLoginResponse>;

public sealed class VerifyVendorOtpCommandValidator : AbstractValidator<VerifyVendorOtpCommand>
{
    public VerifyVendorOtpCommandValidator()
    {
        RuleFor(x => x.Phone)
            .NotEmpty()
            .Matches("^[0-9]{10,15}$")
            .WithMessage("A valid 10+ digit phone number is required.");

        RuleFor(x => x.OtpCode)
            .NotEmpty()
            .Length(4, 8)
            .WithMessage("The OTP is invalid.");

        RuleFor(x => x.OwnerName)
            .MaximumLength(120);
    }
}

public sealed record VendorLoginResponse(
    string AccessToken,
    Guid VendorId,
    string VendorName,
    string Category,
    Guid UserId,
    string UserName,
    string Phone,
    string Status,
    string? RejectionReason,
    IReadOnlyList<VendorSummary> Businesses);

/// <summary>
/// Lightweight vendor summary used in the multi-business login response
/// and the list-my-vendors endpoint.
/// </summary>
public sealed record VendorSummary(
    Guid VendorId,
    string Name,
    string Category,
    string Status,
    bool IsActive);

/// <summary>
/// Lists all vendor businesses linked to the authenticated partner's phone.
/// Supports multi-business partners who own more than one venue/shop.
/// </summary>
public sealed record ListMyVendorsQuery : IRequest<IReadOnlyList<VendorSummary>>;

public sealed class ListMyVendorsHandler : IRequestHandler<ListMyVendorsQuery, IReadOnlyList<VendorSummary>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListMyVendorsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<VendorSummary>> Handle(ListMyVendorsQuery request, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone
            ?? throw new UnauthorizedAccessException("Authenticated phone not found.");

        var vendors = await _context.Vendors
            .AsNoTracking()
            .Where(v => v.ContactPhone == phone)
            .OrderByDescending(v => v.IsApproved)
            .ThenBy(v => v.Name)
            .Select(v => new VendorSummary(
                v.Id,
                v.Name,
                v.Category.ToString(),
                !v.IsActive ? "Rejected" : v.IsApproved ? "Approved" : "Pending",
                v.IsActive))
            .ToListAsync(cancellationToken);

        return vendors;
    }
}
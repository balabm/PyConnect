namespace PondyConnect.Application.Features.Vendor;

using FluentValidation;
using MediatR;
using PondyConnect.Domain.Enums;

/// <summary>Creates a hyper-local push/offer promotion for the vendor.</summary>
public sealed record CreateVendorPromotionCommand(
    PromoType PromoType,
    string Title,
    decimal Cost,
    DateTimeOffset StartsAt,
    DateTimeOffset ExpiresAt,
    string? Description = null,
    double? TargetLatitude = null,
    double? TargetLongitude = null,
    double? TargetRadiusKm = null) : IRequest<CreateVendorPromotionResponse>;

public sealed class CreateVendorPromotionCommandValidator : AbstractValidator<CreateVendorPromotionCommand>
{
    public CreateVendorPromotionCommandValidator()
    {
        RuleFor(x => x.PromoType).IsInEnum();
        RuleFor(x => x.Title).NotEmpty().MaximumLength(160);
        RuleFor(x => x.Description).MaximumLength(1000);
        RuleFor(x => x.Cost).GreaterThanOrEqualTo(0);
        RuleFor(x => x.StartsAt).NotEmpty();
        RuleFor(x => x.ExpiresAt)
            .GreaterThan(x => x.StartsAt)
            .WithMessage("Expiry must be after the start time.");
        RuleFor(x => x.TargetRadiusKm)
            .GreaterThan(0)
            .When(x => x.TargetRadiusKm.HasValue)
            .WithMessage("Target radius must be positive.");
        RuleFor(x => x.TargetLatitude)
            .InclusiveBetween(-90, 90)
            .When(x => x.TargetLatitude.HasValue);
        RuleFor(x => x.TargetLongitude)
            .InclusiveBetween(-180, 180)
            .When(x => x.TargetLongitude.HasValue);
    }
}

public sealed record CreateVendorPromotionResponse(Guid PromotionId, string Status);

/// <summary>List a vendor's promotions.</summary>
public sealed record ListVendorPromotionsQuery() : IRequest<IReadOnlyList<VendorPromotionResponse>>;

public sealed record VendorPromotionResponse(
    Guid PromotionId,
    string PromoType,
    string Title,
    string? Description,
    decimal Cost,
    DateTimeOffset StartsAt,
    DateTimeOffset ExpiresAt,
    bool IsActive,
    double? TargetRadiusKm);
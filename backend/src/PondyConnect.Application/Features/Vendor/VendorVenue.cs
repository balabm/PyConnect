namespace PondyConnect.Application.Features.Vendor;

using FluentValidation;
using MediatR;
using PondyConnect.Domain.Enums;

/// <summary>Operating-hours slice for a venue.</summary>
public sealed record OperatingDayDto(
    DayOfWeek DayOfWeek,
    TimeOnly OpensAt,
    TimeOnly ClosesAt);

public sealed class OperatingDayDtoValidator : AbstractValidator<OperatingDayDto>
{
    public OperatingDayDtoValidator()
    {
        RuleFor(x => x.OpensAt).LessThan(x => x.ClosesAt)
            .WithMessage("Opening time must be before closing time.");
    }
}

/// <summary>Creates a venue (and operating hours) owned by the authenticated vendor.</summary>
public sealed record CreateVendorVenueCommand(
    string Name,
    VenueCategory Category,
    double Latitude,
    double Longitude,
    int MaxCapacity,
    string? Description = null,
    string? Address = null,
    IReadOnlyList<OperatingDayDto>? OperatingHours = null) : IRequest<CreateVendorVenueResponse>;

public sealed class CreateVendorVenueCommandValidator : AbstractValidator<CreateVendorVenueCommand>
{
    public CreateVendorVenueCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(160);
        RuleFor(x => x.MaxCapacity).GreaterThan(0).LessThanOrEqualTo(100_000);
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180);
        RuleFor(x => x.Address).MaximumLength(300);
        RuleFor(x => x.Description).MaximumLength(1000);
        RuleForEach(x => x.OperatingHours).SetValidator(new OperatingDayDtoValidator());
    }
}

public sealed record CreateVendorVenueResponse(Guid VenueId);

/// <summary>Updates a venue owned by the authenticated vendor.</summary>
public sealed record UpdateVendorVenueCommand(
    Guid VenueId,
    string Name,
    VenueCategory Category,
    double Latitude,
    double Longitude,
    int MaxCapacity,
    string? Description = null,
    string? Address = null,
    IReadOnlyList<OperatingDayDto>? OperatingHours = null) : IRequest;

public sealed class UpdateVendorVenueCommandValidator : AbstractValidator<UpdateVendorVenueCommand>
{
    public UpdateVendorVenueCommandValidator()
    {
        RuleFor(x => x.VenueId).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(160);
        RuleFor(x => x.Category).IsInEnum().Must(c => (int)c >= 1).WithMessage("Category is required and must be a valid venue category.");
        RuleFor(x => x.MaxCapacity).GreaterThan(0).LessThanOrEqualTo(100_000);
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180);
        RuleFor(x => x.Address).MaximumLength(300);
        RuleFor(x => x.Description).MaximumLength(1000);
        RuleForEach(x => x.OperatingHours).SetValidator(new OperatingDayDtoValidator());
    }
}

/// <summary>Deactivates (soft-delete) a venue owned by the vendor.</summary>
public sealed record DeactivateVendorVenueCommand(Guid VenueId) : IRequest;

/// <summary>Toggles or sets the active status of a venue owned by the authenticated vendor.
/// When <paramref name="IsActive"/> is null, the current state is toggled.
/// When provided, the venue is set to the requested state.</summary>
public sealed record ToggleVenueAvailabilityCommand(Guid VenueId, bool? IsActive = null) : IRequest<ToggleVenueAvailabilityResponse>;

public sealed record ToggleVenueAvailabilityResponse(bool IsActive);

/// <summary>Lists venues owned by the authenticated vendor.</summary>
public sealed record ListVendorVenuesQuery() : IRequest<IReadOnlyList<VendorVenueResponse>>;

public sealed record OperatingHoursView(
    DayOfWeek DayOfWeek,
    string OpensAt,
    string ClosesAt);

public sealed record VendorVenueResponse(
    Guid VenueId,
    string Name,
    string Category,
    string? Description,
    string? Address,
    double Latitude,
    double Longitude,
    int MaxCapacity,
    int CurrentCapacity,
    int CheckedInCount,
    bool IsActive,
    IReadOnlyList<OperatingHoursView> OperatingHours);
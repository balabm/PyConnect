namespace PondyConnect.Application.Features.Venues;

using FluentValidation;
using MediatR;

public sealed record VenueFilterQuery(
    int? Category,
    bool OnlyActive = true,
    int Page = 1,
    int PageSize = 20) : IRequest<IReadOnlyList<VenueFilterResponse>>;

public sealed class VenueFilterQueryValidator : AbstractValidator<VenueFilterQuery>
{
    public VenueFilterQueryValidator()
    {
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1);
        RuleFor(x => x.PageSize).InclusiveBetween(1, 100);
    }
}

public sealed record GetVenueByIdQuery(Guid Id) : IRequest<VenueDetailResponse>;

public sealed class GetVenueByIdQueryValidator : AbstractValidator<GetVenueByIdQuery>
{
    public GetVenueByIdQueryValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public sealed record VenueFilterResponse(
    Guid Id,
    string Name,
    string Category,
    double Latitude,
    double Longitude,
    int MaxCapacity,
    int Occupancy,
    bool IsOpen,
    string? Address,
    bool IsPriorityPingActive,
    string? ImageUrl,
    double? Rating,
    int ReviewCount);

public sealed record VenueDetailResponse(
    Guid Id,
    string Name,
    string Category,
    double Latitude,
    double Longitude,
    int MaxCapacity,
    int Occupancy,
    bool IsOpen,
    string? Address,
    string? Description,
    string? ImageUrl,
    double? Rating,
    int ReviewCount,
    bool IsPriorityPingActive,
    IReadOnlyList<VenueAvailabilityResponse> Availability);

public sealed record VenueAvailabilityResponse(
    DayOfWeek DayOfWeek,
    TimeOnly OpensAt,
    TimeOnly ClosesAt);
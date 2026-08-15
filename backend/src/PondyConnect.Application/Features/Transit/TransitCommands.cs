namespace PondyConnect.Application.Features.Transit;

using FluentValidation;
using MediatR;
using PondyConnect.Domain.Enums;

public sealed record CreateTransitTripCommand(
    Guid HubId,
    string ArrivalFrom,
    string ArrivalMode,
    DateTimeOffset ArrivalAt,
    int PartySize,
    decimal Price,
    string? DropOffLocation = null,
    string? Notes = null) : IRequest<CreateTransitTripResponse>;

public sealed class CreateTransitTripCommandValidator : AbstractValidator<CreateTransitTripCommand>
{
    public CreateTransitTripCommandValidator()
    {
        RuleFor(x => x.HubId).NotEmpty();
        RuleFor(x => x.ArrivalFrom).NotEmpty().MaximumLength(120);
        RuleFor(x => x.ArrivalMode).NotEmpty().MaximumLength(20);
        RuleFor(x => x.ArrivalAt).GreaterThan(DateTimeOffset.UtcNow.AddMinutes(-5));
        RuleFor(x => x.PartySize).InclusiveBetween(1, 10);
        RuleFor(x => x.Price).GreaterThanOrEqualTo(0);
        RuleFor(x => x.DropOffLocation).MaximumLength(200);
        RuleFor(x => x.Notes).MaximumLength(500);
    }
}

public sealed record CreateTransitTripResponse(Guid TripId, string Status, decimal Amount);

public sealed record ListTransitHubsQuery(
    TransitHubKind? Kind = null,
    bool OnlyActive = true) : IRequest<IReadOnlyList<TransitHubResponse>>;

public sealed record TransitHubResponse(
    Guid Id,
    string Name,
    string Kind,
    double Latitude,
    double Longitude,
    string? Address);

public sealed record GetTransitHubQuery(Guid HubId) : IRequest<TransitHubDetailResponse>;

public sealed record TransitHubDetailResponse(
    Guid Id,
    string Name,
    string Kind,
    double Latitude,
    double Longitude,
    string? Address,
    bool IsActive);

public sealed record ListUserTripsQuery(
    Guid UserId,
    TransitStatus? Status = null) : IRequest<IReadOnlyList<TransitTripResponse>>;

public sealed record TransitTripResponse(
    Guid Id,
    string HubName,
    string ArrivalFrom,
    string ArrivalMode,
    DateTimeOffset ArrivalAt,
    int PartySize,
    string? DropOffLocation,
    string Status,
    decimal Price,
    string PaymentStatus,
    DateTimeOffset? CompletedAt);
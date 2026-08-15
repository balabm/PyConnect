namespace PondyConnect.Application.Features.Bookings;

using FluentValidation;
using MediatR;

public sealed record CreateBookingCommand(
    Guid VenueId,
    int Seats,
    DateTimeOffset ScheduledFor,
    string? Notes) : IRequest<CreateBookingResponse>;

public sealed class CreateBookingCommandValidator : AbstractValidator<CreateBookingCommand>
{
    public CreateBookingCommandValidator()
    {
        RuleFor(x => x.VenueId).NotEmpty();
        RuleFor(x => x.Seats).InclusiveBetween(1, 200);
        RuleFor(x => x.ScheduledFor).GreaterThan(DateTimeOffset.UtcNow.AddMinutes(-1));
    }
}

public sealed record CreateBookingResponse(Guid BookingId, string Status, decimal Amount, string PassToken);
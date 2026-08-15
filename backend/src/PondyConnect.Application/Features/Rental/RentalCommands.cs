namespace PondyConnect.Application.Features.Rental;

using FluentValidation;
using MediatR;
using PondyConnect.Domain.Enums;

public sealed record CreateScooterRentalCommand(
    Guid VendorId,
    string VehicleName,
    DateTimeOffset RentalStart,
    DateTimeOffset RentalEnd,
    decimal RatePerHour,
    string? VehiclePlate = null,
    string? Notes = null) : IRequest<CreateScooterRentalResponse>;

public sealed class CreateScooterRentalCommandValidator : AbstractValidator<CreateScooterRentalCommand>
{
    public CreateScooterRentalCommandValidator()
    {
        RuleFor(x => x.VendorId).NotEmpty();
        RuleFor(x => x.VehicleName).NotEmpty().MaximumLength(80);
        RuleFor(x => x.RentalStart).GreaterThan(DateTimeOffset.UtcNow.AddMinutes(-5));
        RuleFor(x => x.RentalEnd).GreaterThan(x => x.RentalStart);
        RuleFor(x => x.RatePerHour).GreaterThanOrEqualTo(0);
        RuleFor(x => x.VehiclePlate).MaximumLength(20);
        RuleFor(x => x.Notes).MaximumLength(500);
    }
}

public sealed record CreateScooterRentalResponse(Guid RentalId, string Status, decimal TotalAmount);

public sealed record ListUserRentalsQuery(
    Guid UserId,
    RentalStatus? Status = null) : IRequest<IReadOnlyList<ScooterRentalResponse>>;

public sealed record ScooterRentalResponse(
    Guid Id,
    string VendorName,
    string VehicleName,
    string? VehiclePlate,
    DateTimeOffset RentalStart,
    DateTimeOffset RentalEnd,
    decimal RatePerHour,
    decimal TotalAmount,
    string Status,
    string PaymentStatus);
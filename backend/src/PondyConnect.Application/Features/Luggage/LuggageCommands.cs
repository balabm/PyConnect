namespace PondyConnect.Application.Features.Luggage;

using FluentValidation;
using MediatR;
using PondyConnect.Domain.Enums;

public sealed record CreateLuggageDropOffCommand(
    Guid VendorId,
    DateTimeOffset ScheduledFor,
    DateTimeOffset DroppedAt,
    int BagCount,
    decimal RatePerHour,
    string? Notes = null) : IRequest<CreateLuggageDropOffResponse>;

public sealed class CreateLuggageDropOffCommandValidator : AbstractValidator<CreateLuggageDropOffCommand>
{
    public CreateLuggageDropOffCommandValidator()
    {
        RuleFor(x => x.VendorId).NotEmpty();
        RuleFor(x => x.ScheduledFor).GreaterThan(DateTimeOffset.UtcNow.AddMinutes(-5));
        RuleFor(x => x.DroppedAt).GreaterThan(DateTimeOffset.UtcNow.AddMinutes(-5));
        RuleFor(x => x.BagCount).InclusiveBetween(1, 20);
        RuleFor(x => x.RatePerHour).GreaterThanOrEqualTo(0);
        RuleFor(x => x.Notes).MaximumLength(500);
    }
}

public sealed record CreateLuggageDropOffResponse(Guid DropOffId, string Status, decimal TotalAmount);

public sealed record ListUserLuggageQuery(
    Guid UserId,
    LuggageStatus? Status = null) : IRequest<IReadOnlyList<LuggageDropOffResponse>>;

public sealed record LuggageDropOffResponse(
    Guid Id,
    string VendorName,
    DateTimeOffset ScheduledFor,
    DateTimeOffset DroppedAt,
    int BagCount,
    decimal RatePerHour,
    decimal TotalAmount,
    string Status,
    string PaymentStatus,
    DateTimeOffset? PickedUpAt);

public sealed record CancelLuggageDropOffCommand(Guid DropOffId) : IRequest<CancelLuggageDropOffResponse>;

public sealed class CancelLuggageDropOffCommandValidator : AbstractValidator<CancelLuggageDropOffCommand>
{
    public CancelLuggageDropOffCommandValidator()
    {
        RuleFor(x => x.DropOffId).NotEmpty();
    }
}

public sealed record CancelLuggageDropOffResponse(Guid Id, string Status);

public sealed record GetLuggageDropOffQuery(Guid Id) : IRequest<LuggageDropOffResponse>;

public sealed class GetLuggageDropOffQueryValidator : AbstractValidator<GetLuggageDropOffQuery>
{
    public GetLuggageDropOffQueryValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public sealed record ListVendorLuggageQuery(
    LuggageStatus? Status = null) : IRequest<IReadOnlyList<LuggageDropOffResponse>>;

public sealed record MarkLuggageCollectedCommand(Guid DropOffId) : IRequest<LuggageDropOffResponse>;

public sealed class MarkLuggageCollectedCommandValidator : AbstractValidator<MarkLuggageCollectedCommand>
{
    public MarkLuggageCollectedCommandValidator()
    {
        RuleFor(x => x.DropOffId).NotEmpty();
    }
}
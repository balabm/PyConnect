namespace PondyConnect.Application.Features.Auth;

using FluentValidation;
using MediatR;

public sealed record RequestOtpCommand(string Phone, string? Name) : IRequest<OtpRequestedResponse>;

public sealed class RequestOtpCommandValidator : AbstractValidator<RequestOtpCommand>
{
    public RequestOtpCommandValidator()
    {
        RuleFor(x => x.Phone)
            .NotEmpty()
            .Matches("^[0-9]{10,15}$")
            .WithMessage("A valid 10+ digit phone number is required.");

        RuleFor(x => x.Name)
            .MaximumLength(120);
    }
}
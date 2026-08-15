namespace PondyConnect.Application.Features.Auth;

using FluentValidation;
using MediatR;

public sealed record VerifyOtpCommand(string Phone, string Otp, string? Name) : IRequest<AuthResponse>;

public sealed class VerifyOtpCommandValidator : AbstractValidator<VerifyOtpCommand>
{
    public VerifyOtpCommandValidator()
    {
        RuleFor(x => x.Phone)
            .NotEmpty()
            .Matches("^[0-9]{10,15}$")
            .WithMessage("A valid 10+ digit phone number is required.");

        RuleFor(x => x.Otp)
            .NotEmpty()
            .Length(4, 8)
            .WithMessage("The OTP is invalid.");
    }
}
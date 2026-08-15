namespace PondyConnect.Application.Features.Auth;

using FluentValidation;
using MediatR;

/// <summary>
/// Links a phone-verified user to a Google account.
/// </summary>
public sealed record LinkGoogleCommand(string IdToken) : IRequest<AuthResponse>;

public sealed class LinkGoogleCommandValidator : AbstractValidator<LinkGoogleCommand>
{
    public LinkGoogleCommandValidator()
    {
        RuleFor(x => x.IdToken).NotEmpty().WithMessage("Google idToken is required.");
    }
}

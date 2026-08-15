namespace PondyConnect.Application.Features.Auth;

using FluentValidation;
using MediatR;

/// <summary>
/// Verifies a Google ID token and returns a PondyConnect JWT if the user has
/// already linked their Google account. Otherwise indicates that a phone number
/// must be collected and verified.
/// </summary>
public sealed record GoogleSignInCommand(string IdToken) : IRequest<SocialAuthResponse>;

public sealed class GoogleSignInCommandValidator : AbstractValidator<GoogleSignInCommand>
{
    public GoogleSignInCommandValidator()
    {
        RuleFor(x => x.IdToken).NotEmpty().WithMessage("Google idToken is required.");
    }
}

namespace PondyConnect.Application.Features.Auth;

using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using PondyConnect.Application.Common.Interfaces;

public sealed class GoogleSignInCommandHandler : IRequestHandler<GoogleSignInCommand, SocialAuthResponse>
{
    private readonly IGoogleTokenVerifier _tokenVerifier;
    private readonly IApplicationDbContext _dbContext;
    private readonly IJwtTokenFactory _jwtTokenFactory;
    private readonly IConfiguration _configuration;

    public GoogleSignInCommandHandler(
        IGoogleTokenVerifier tokenVerifier,
        IApplicationDbContext dbContext,
        IJwtTokenFactory jwtTokenFactory,
        IConfiguration configuration)
    {
        _tokenVerifier = tokenVerifier;
        _dbContext = dbContext;
        _jwtTokenFactory = jwtTokenFactory;
        _configuration = configuration;
    }

    public async Task<SocialAuthResponse> Handle(GoogleSignInCommand request, CancellationToken cancellationToken)
    {
        var clientId = _configuration["Auth:Google:WebClientId"];
        var googleUser = await _tokenVerifier.VerifyIdTokenAsync(request.IdToken, clientId, cancellationToken);

        if (googleUser is null)
            throw new UnauthorizedAccessException("Google sign-in token is invalid or expired.");

        var user = await _dbContext.Users
            .FirstOrDefaultAsync(u => u.GoogleId == googleUser.GoogleId || u.Email == googleUser.Email, cancellationToken);

        // No existing Google-linked account: ask the client for a phone number.
        if (user is null)
        {
            return new SocialAuthResponse(
                AccessToken: null,
                NeedsPhone: true,
                Name: googleUser.Name,
                Phone: null,
                Role: null,
                Message: "Please provide a phone number to complete your account.");
        }

        if (!user.IsActive)
            throw new UnauthorizedAccessException("Account is disabled.");

        user.RecordLogin();
        await _dbContext.SaveChangesAsync(cancellationToken);

        var accessToken = _jwtTokenFactory.CreateAccessToken(user.Id, user.Phone, user.Role.ToString());

        return new SocialAuthResponse(
            accessToken,
            NeedsPhone: false,
            user.Name,
            user.Phone,
            user.Role.ToString(),
            IsProMember: user.IsProMember,
            Message: "Signed in with Google.");
    }
}

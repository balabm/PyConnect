namespace PondyConnect.Application.Features.Auth;

using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using PondyConnect.Application.Common.Interfaces;

public sealed class LinkGoogleCommandHandler : IRequestHandler<LinkGoogleCommand, AuthResponse>
{
    private readonly IGoogleTokenVerifier _tokenVerifier;
    private readonly ICurrentUserService _currentUser;
    private readonly IApplicationDbContext _dbContext;
    private readonly IJwtTokenFactory _jwtTokenFactory;
    private readonly IConfiguration _configuration;

    public LinkGoogleCommandHandler(
        IGoogleTokenVerifier tokenVerifier,
        ICurrentUserService currentUser,
        IApplicationDbContext dbContext,
        IJwtTokenFactory jwtTokenFactory,
        IConfiguration configuration)
    {
        _tokenVerifier = tokenVerifier;
        _currentUser = currentUser;
        _dbContext = dbContext;
        _jwtTokenFactory = jwtTokenFactory;
        _configuration = configuration;
    }

    public async Task<AuthResponse> Handle(LinkGoogleCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User must be authenticated to link Google.");

        var clientId = _configuration["Auth:Google:WebClientId"];
        var googleUser = await _tokenVerifier.VerifyIdTokenAsync(request.IdToken, clientId, cancellationToken);

        if (googleUser is null)
            throw new UnauthorizedAccessException("Google token is invalid or expired.");

        // Ensure the Google account is not already linked to another user.
        var existing = await _dbContext.Users
            .FirstOrDefaultAsync(
                u => u.GoogleId == googleUser.GoogleId && u.Id != userId,
                cancellationToken);

        if (existing is not null)
            throw new InvalidOperationException("This Google account is already linked to another profile.");

        var user = await _dbContext.Users
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new UnauthorizedAccessException("User not found.");

        user.LinkGoogle(
            googleUser.GoogleId,
            googleUser.Email,
            googleUser.IsEmailVerified,
            googleUser.PictureUrl);

        if (!string.IsNullOrWhiteSpace(googleUser.Name) && string.IsNullOrWhiteSpace(user.Name))
            user.UpdateProfile(googleUser.Name);

        user.RecordLogin();
        await _dbContext.SaveChangesAsync(cancellationToken);

        var accessToken = _jwtTokenFactory.CreateAccessToken(user.Id, user.Phone, user.Role.ToString());

        return new AuthResponse(
            accessToken,
            user.Id,
            user.Name,
            user.Phone,
            user.Role.ToString(),
            user.IsProMember,
            user.IsVerifiedLocal);
    }
}

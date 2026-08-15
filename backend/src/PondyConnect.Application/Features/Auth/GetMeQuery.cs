namespace PondyConnect.Application.Features.Auth;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;

public sealed record GetMeQuery : IRequest<AuthResponse>;

public sealed class GetMeQueryHandler : IRequestHandler<GetMeQuery, AuthResponse>
{
    private readonly ICurrentUserService _currentUser;
    private readonly IApplicationDbContext _context;
    private readonly IJwtTokenFactory _jwtTokenFactory;

    public GetMeQueryHandler(
        ICurrentUserService currentUser,
        IApplicationDbContext context,
        IJwtTokenFactory jwtTokenFactory)
    {
        _currentUser = currentUser;
        _context = context;
        _jwtTokenFactory = jwtTokenFactory;
    }

    public async Task<AuthResponse> Handle(GetMeQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new UnauthorizedAccessException("User not found.");

        var accessToken = _jwtTokenFactory.CreateAccessToken(user.Id, user.Phone, user.Role.ToString());

        return new AuthResponse(accessToken, user.Id, user.Name, user.Phone, user.Role.ToString(), user.IsProMember, user.IsVerifiedLocal);
    }
}

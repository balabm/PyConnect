namespace PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Issues signed JWT access tokens for authenticated users.
/// </summary>
public interface IJwtTokenFactory
{
    string CreateAccessToken(Guid userId, string phone, string role);
}

public interface ICurrentUserService
{
    Guid? UserId { get; }
    string? Phone { get; }
    string? Role { get; }
}
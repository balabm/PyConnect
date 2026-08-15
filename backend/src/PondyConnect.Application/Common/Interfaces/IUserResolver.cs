namespace PondyConnect.Application.Common.Interfaces;

using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

/// <summary>
/// Upserts a user by phone and returns the current identity.
/// </summary>
public interface IUserResolver
{
    Task<User> GetOrCreateAsync(string name, string phone, UserRole role, CancellationToken cancellationToken = default);
}
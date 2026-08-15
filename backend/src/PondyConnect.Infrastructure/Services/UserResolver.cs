namespace PondyConnect.Infrastructure.Services;

using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Infrastructure.Persistence;

public sealed class UserResolver : IUserResolver
{
    private readonly ApplicationDbContext _context;

    public UserResolver(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<User> GetOrCreateAsync(string name, string phone, UserRole role, CancellationToken cancellationToken = default)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Phone == phone, cancellationToken);
        if (user is not null)
        {
            user.RecordLogin();
            await _context.SaveChangesAsync(cancellationToken);
            return user;
        }

        var created = User.Create(name, phone, role);
        _context.Users.Add(created);
        await _context.SaveChangesAsync(cancellationToken);
        return created;
    }
}
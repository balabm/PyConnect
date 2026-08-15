namespace PondyConnect.Application.Features.RideHailing;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

public sealed record GetDriverWalletQuery() : IRequest<DriverWalletResponse>;

public sealed record DriverWalletResponse(
    decimal Balance,
    IReadOnlyList<LedgerEntrySummary> RecentEntries);

public sealed record LedgerEntrySummary(
    Guid Id,
    decimal Amount,
    string TransactionType,
    string? Reference,
    DateTimeOffset CreatedAt);

public sealed class GetDriverWalletHandler : IRequestHandler<GetDriverWalletQuery, DriverWalletResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetDriverWalletHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<DriverWalletResponse> Handle(GetDriverWalletQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");

        var driver = await _context.Drivers.AsNoTracking()
            .FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken);

        if (driver is null)
            throw new InvalidOperationException("Driver profile not found.");

        var entries = await _context.DriverLedgerEntries.AsNoTracking()
            .Where(e => e.DriverId == driver.Id)
            .ToListAsync(cancellationToken);

        var balance = entries.Sum(e => e.Amount);

        var recent = entries
            .OrderByDescending(e => e.CreatedAt)
            .Take(20)
            .Select(e => new LedgerEntrySummary(
                e.Id,
                e.Amount,
                e.TransactionType.ToString(),
                e.Reference,
                e.CreatedAt))
            .ToList();

        return new DriverWalletResponse(balance, recent);
    }
}

namespace PondyConnect.Application.Features.RideHailing;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

public sealed record GetDriverByUserIdQuery(Guid UserId) : IRequest<DriverIdentity?>;

public sealed record DriverIdentity(Guid Id, string Name);

public sealed class GetDriverByUserIdHandler : IRequestHandler<GetDriverByUserIdQuery, DriverIdentity?>
{
    private readonly IApplicationDbContext _context;

    public GetDriverByUserIdHandler(IApplicationDbContext context) => _context = context;

    public async Task<DriverIdentity?> Handle(GetDriverByUserIdQuery request, CancellationToken cancellationToken)
    {
        var driver = await _context.Drivers.AsNoTracking()
            .FirstOrDefaultAsync(d => d.UserId == request.UserId, cancellationToken);

        return driver is null ? null : new DriverIdentity(driver.Id, driver.Name);
    }
}

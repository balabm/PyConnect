namespace PondyConnect.Application.Features.RideHailing;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

public sealed record GetAvailableTasksQuery() : IRequest<IReadOnlyList<DispatchTaskResponse>>;

public sealed record DispatchTaskResponse(
    Guid Id,
    string TaskType,
    string PickupAddress,
    string DropoffAddress,
    decimal DriverEarnings,
    string Status,
    Guid? DriverId);

public sealed class GetAvailableTasksHandler : IRequestHandler<GetAvailableTasksQuery, IReadOnlyList<DispatchTaskResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetAvailableTasksHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<DispatchTaskResponse>> Handle(GetAvailableTasksQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");

        var driver = await _context.Drivers.AsNoTracking()
            .FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken);

        if (driver is null)
            throw new InvalidOperationException("Driver profile not found.");

        var tasks = await _context.DispatchTasks.AsNoTracking()
            .Where(t => t.Status == DispatchTaskStatus.Available
                || (t.DriverId == driver.Id
                    && t.Status != DispatchTaskStatus.Completed
                    && t.Status != DispatchTaskStatus.Cancelled))
            .ToListAsync(cancellationToken);

        return tasks
            .Select(t => new DispatchTaskResponse(
                t.Id,
                t.TaskType.ToString(),
                t.PickupAddress,
                t.DropoffAddress,
                t.DriverEarnings,
                t.Status.ToString(),
                t.DriverId))
            .ToList();
    }
}

public sealed record AcceptTaskCommand(Guid TaskId) : IRequest<DispatchTaskResponse>;

public sealed class AcceptTaskHandler : IRequestHandler<AcceptTaskCommand, DispatchTaskResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public AcceptTaskHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<DispatchTaskResponse> Handle(AcceptTaskCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");

        var driver = await _context.Drivers.AsNoTracking()
            .FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Driver profile not found.");

        var task = await _context.DispatchTasks
            .FirstOrDefaultAsync(t => t.Id == request.TaskId, cancellationToken)
            ?? throw new InvalidOperationException("Task not found.");

        task.Assign(driver.Id);
        await _context.SaveChangesAsync(cancellationToken);

        return new DispatchTaskResponse(
            task.Id,
            task.TaskType.ToString(),
            task.PickupAddress,
            task.DropoffAddress,
            task.DriverEarnings,
            task.Status.ToString(),
            task.DriverId);
    }
}

public sealed record CompleteTaskCommand(Guid TaskId) : IRequest<Unit>;

public sealed class CompleteTaskHandler : IRequestHandler<CompleteTaskCommand, Unit>
{
    private readonly IApplicationDbContext _context;

    public CompleteTaskHandler(IApplicationDbContext context) => _context = context;

    public async Task<Unit> Handle(CompleteTaskCommand request, CancellationToken cancellationToken)
    {
        var task = await _context.DispatchTasks
            .FirstOrDefaultAsync(t => t.Id == request.TaskId, cancellationToken)
            ?? throw new InvalidOperationException("Task not found.");

        task.Complete();
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

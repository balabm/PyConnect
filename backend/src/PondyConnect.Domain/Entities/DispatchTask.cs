namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

public sealed class DispatchTask : BaseEntity
{
    public DispatchTaskType TaskType { get; private set; }

    public Guid? SourceEntityId { get; private set; }

    public Guid? DriverId { get; private set; }

    public GeoLocation PickupLocation { get; private set; } = GeoLocation.Zero;

    public GeoLocation DropoffLocation { get; private set; } = GeoLocation.Zero;

    public string PickupAddress { get; private set; } = string.Empty;

    public string DropoffAddress { get; private set; } = string.Empty;

    public decimal DriverEarnings { get; private set; }

    public DispatchTaskStatus Status { get; private set; } = DispatchTaskStatus.Available;

    private DispatchTask()
    {
    }

    public static DispatchTask Create(
        DispatchTaskType taskType,
        GeoLocation pickupLocation,
        GeoLocation dropoffLocation,
        string pickupAddress,
        string dropoffAddress,
        decimal driverEarnings,
        Guid? sourceEntityId = null)
    {
        return new DispatchTask
        {
            TaskType = taskType,
            SourceEntityId = sourceEntityId,
            PickupLocation = pickupLocation,
            DropoffLocation = dropoffLocation,
            PickupAddress = pickupAddress,
            DropoffAddress = dropoffAddress,
            DriverEarnings = driverEarnings,
            Status = DispatchTaskStatus.Available
        };
    }

    public void Assign(Guid driverId)
    {
        if (Status != DispatchTaskStatus.Available)
            throw new InvalidOperationException("Task is no longer available for assignment.");

        DriverId = driverId;
        Status = DispatchTaskStatus.Assigned;
        MarkUpdated();
    }

    public void Start()
    {
        if (Status != DispatchTaskStatus.Assigned)
            throw new InvalidOperationException("Task must be assigned before it can be started.");

        Status = DispatchTaskStatus.InProgress;
        MarkUpdated();
    }

    public void Complete()
    {
        if (Status != DispatchTaskStatus.InProgress && Status != DispatchTaskStatus.Assigned)
            throw new InvalidOperationException("Task cannot be completed from its current state.");

        Status = DispatchTaskStatus.Completed;
        MarkUpdated();
    }

    public void Cancel()
    {
        if (Status == DispatchTaskStatus.Completed || Status == DispatchTaskStatus.Cancelled)
            return;

        Status = DispatchTaskStatus.Cancelled;
        MarkUpdated();
    }
}

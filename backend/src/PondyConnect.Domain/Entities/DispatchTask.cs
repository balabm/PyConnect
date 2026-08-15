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

    /// <summary>
    /// Marks the driver as arrived at the store/restaurant for pickup.
    /// Only valid for food/essentials delivery tasks that are in progress.
    /// </summary>
    public void MarkArrivedAtStore()
    {
        if (Status != DispatchTaskStatus.InProgress && Status != DispatchTaskStatus.Assigned)
            throw new InvalidOperationException("Task must be in progress before arriving at store.");

        Status = DispatchTaskStatus.ArrivedAtStore;
        MarkUpdated();
    }

    /// <summary>
    /// Marks the order as picked up and the driver as en route to the customer.
    /// Only valid after arriving at the store.
    /// </summary>
    public void MarkOutForDelivery()
    {
        if (Status != DispatchTaskStatus.ArrivedAtStore)
            throw new InvalidOperationException("Task must be at store before going out for delivery.");

        Status = DispatchTaskStatus.OutForDelivery;
        MarkUpdated();
    }

    public void Complete()
    {
        if (Status is not (DispatchTaskStatus.InProgress or DispatchTaskStatus.Assigned or DispatchTaskStatus.OutForDelivery))
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

    /// <summary>
    /// Emergency release: unassigns the current driver and pushes the task
    /// back to the Available state so it can be re-dispatched to the next
    /// nearest driver. Called when the driver has a breakdown or emergency
    /// and cannot complete the trip. Only valid for tasks that are currently
    /// assigned to a driver (Assigned, InProgress, ArrivedAtStore, OutForDelivery).
    /// </summary>
    public void EmergencyRelease()
    {
        if (Status is not (DispatchTaskStatus.Assigned
            or DispatchTaskStatus.InProgress
            or DispatchTaskStatus.ArrivedAtStore
            or DispatchTaskStatus.OutForDelivery))
            throw new InvalidOperationException("Only active tasks can be emergency-released.");

        DriverId = null;
        Status = DispatchTaskStatus.Available;
        MarkUpdated();
    }
}

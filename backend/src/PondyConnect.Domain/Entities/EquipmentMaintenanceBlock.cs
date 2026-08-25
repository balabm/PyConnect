namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A date range during which an equipment item is unavailable for
/// rental (e.g. scheduled maintenance, repairs, or hold).
/// </summary>
public sealed class EquipmentMaintenanceBlock : BaseEntity
{
    public Guid EquipmentItemId { get; private set; }

    public Guid VendorId { get; private set; }

    public DateTimeOffset StartDate { get; private set; }

    public DateTimeOffset EndDate { get; private set; }

    /// <summary>
    /// "Maintenance", "Repair", or "Hold".
    /// </summary>
    public string Reason { get; private set; } = "Maintenance";

    public string? Notes { get; private set; }

    private EquipmentMaintenanceBlock() { }

    public static EquipmentMaintenanceBlock Create(
        Guid equipmentItemId,
        Guid vendorId,
        DateTimeOffset startDate,
        DateTimeOffset endDate,
        string reason = "Maintenance",
        string? notes = null)
    {
        if (equipmentItemId == Guid.Empty)
            throw new ArgumentException("Equipment item ID is required.", nameof(equipmentItemId));
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        if (endDate <= startDate)
            throw new ArgumentException("End date must be after start date.");

        return new EquipmentMaintenanceBlock
        {
            EquipmentItemId = equipmentItemId,
            VendorId = vendorId,
            StartDate = startDate,
            EndDate = endDate,
            Reason = reason,
            Notes = notes
        };
    }

    /// <summary>
    /// Returns true if the block overlaps with the given date range.
    /// </summary>
    public bool Overlaps(DateTimeOffset start, DateTimeOffset end)
        => StartDate < end && start < EndDate;
}

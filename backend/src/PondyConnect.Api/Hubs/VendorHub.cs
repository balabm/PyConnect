namespace PondyConnect.Api.Hubs;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

/// <summary>
/// Consumer-facing hub for real-time vendor status updates.
/// When a vendor toggles their "Accepting Orders" master switch, the
/// backend broadcasts a <c>VendorStatusChanged</c> event to all connected
/// clients so restaurant cards are greyed out and "Add to Cart" buttons
/// are disabled instantly — without requiring a page refresh.
/// </summary>
[AllowAnonymous]
public sealed class VendorHub : Hub
{
    /// <summary>
    /// Join a vendor-specific group to receive status updates for a
    /// particular vendor (e.g. when viewing their menu).
    /// </summary>
    public Task JoinVendorChannel(Guid vendorId) =>
        Groups.AddToGroupAsync(Context.ConnectionId, $"vendor:{vendorId}");

    public Task LeaveVendorChannel(Guid vendorId) =>
        Groups.RemoveFromGroupAsync(Context.ConnectionId, $"vendor:{vendorId}");
}

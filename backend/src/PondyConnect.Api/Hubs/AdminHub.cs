namespace PondyConnect.Api.Hubs;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

[Authorize(Roles = "Admin")]
public sealed class AdminHub : Hub
{
    public Task JoinAdminGroup() => Groups.AddToGroupAsync(Context.ConnectionId, "admins");

    public Task LeaveAdminGroup() => Groups.RemoveFromGroupAsync(Context.ConnectionId, "admins");

    public Task JoinCriticalQueue() => Groups.AddToGroupAsync(Context.ConnectionId, "critical-tickets");

    public Task LeaveCriticalQueue() => Groups.RemoveFromGroupAsync(Context.ConnectionId, "critical-tickets");
}

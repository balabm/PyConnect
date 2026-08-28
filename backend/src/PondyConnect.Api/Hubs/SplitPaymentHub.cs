namespace PondyConnect.Api.Hubs;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

/// <summary>
/// SignalR hub for real-time split payment updates.
/// The creator of a split payment pool joins a group named after the pool's
/// deep-link slug. When a friend claims or pays a share, the backend pushes
/// an update to the group so the creator's progress bar fills in real-time.
/// </summary>
[Authorize]
public sealed class SplitPaymentHub : Hub
{
    /// <summary>
    /// Join the group for a specific split payment pool (by deep-link slug).
    /// The creator calls this when they open the split payment screen.
    /// </summary>
    public Task JoinPool(string slug)
    {
        if (!string.IsNullOrWhiteSpace(slug))
            return Groups.AddToGroupAsync(Context.ConnectionId, $"split:{slug}");
        return Task.CompletedTask;
    }

    /// <summary>
    /// Leave the group for a split payment pool.
    /// </summary>
    public Task LeavePool(string slug)
    {
        if (!string.IsNullOrWhiteSpace(slug))
            return Groups.RemoveFromGroupAsync(Context.ConnectionId, $"split:{slug}");
        return Task.CompletedTask;
    }
}

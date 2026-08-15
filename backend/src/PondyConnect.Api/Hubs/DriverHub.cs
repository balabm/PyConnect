namespace PondyConnect.Api.Hubs;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using PondyConnect.Api.Services;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// Driver-facing hub for ride offers and live location updates.
/// Drivers join a per-driver group for targeted ride offers.
/// Location updates go to the in-memory DriverLocationStore (not DB).
/// </summary>
[Authorize]
public sealed class DriverHub : Hub
{
    private readonly DriverLocationStore _locationStore;
    private readonly ILogger<DriverHub> _logger;

    public DriverHub(DriverLocationStore locationStore, ILogger<DriverHub> logger)
    {
        _locationStore = locationStore;
        _logger = logger;
    }

    public override Task OnConnectedAsync()
    {
        _logger.LogInformation("DriverHub connection established: {ConnectionId}", Context.ConnectionId);
        return base.OnConnectedAsync();
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        if (exception != null)
            _logger.LogWarning(exception, "DriverHub connection {ConnectionId} disconnected with error", Context.ConnectionId);
        else
            _logger.LogInformation("DriverHub connection {ConnectionId} disconnected", Context.ConnectionId);
        return base.OnDisconnectedAsync(exception);
    }

    public Task JoinDriverGroup() => Groups.AddToGroupAsync(Context.ConnectionId, "drivers");

    public Task LeaveDriverGroup() => Groups.RemoveFromGroupAsync(Context.ConnectionId, "drivers");

    /// <summary>
    /// Join a per-driver group for targeted ride offers. Called when driver
    /// connects and their driverId is known.
    /// </summary>
    public Task JoinDriverChannel(Guid driverId) => Groups.AddToGroupAsync(Context.ConnectionId, $"driver:{driverId}");

    public Task LeaveDriverChannel(Guid driverId) => Groups.RemoveFromGroupAsync(Context.ConnectionId, $"driver:{driverId}");

    /// <summary>
    /// Update driver location in real-time. Stored in-memory only (not DB)
    /// for performance. Called every 3-5 seconds while online.
    /// </summary>
    public Task UpdateLocation(double latitude, double longitude, double? heading = null)
    {
        try
        {
            // Validate coordinates before storing
            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180)
            {
                _logger.LogWarning("Invalid location update from {ConnectionId}: lat={Lat}, lng={Lng}", Context.ConnectionId, latitude, longitude);
                return Task.CompletedTask;
            }

            _locationStore.Update(GetDriverIdFromContext(), latitude, longitude, heading);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating location for connection {ConnectionId}", Context.ConnectionId);
        }
        return Task.CompletedTask;
    }

    private Guid GetDriverIdFromContext()
    {
        // The driverId is passed as a query param when connecting, or from claims
        var driverIdStr = Context.GetHttpContext()?.Request.Query["driverId"].ToString();
        if (Guid.TryParse(driverIdStr, out var driverId))
            return driverId;

        // Fallback: try from user claims
        var userIdStr = Context.User?.FindFirst("nameid")?.Value ?? Context.User?.FindFirst("sub")?.Value;
        if (Guid.TryParse(userIdStr, out var userId))
            return userId;

        return Guid.Empty;
    }
}

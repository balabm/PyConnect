namespace PondyConnect.Api.Services;

using Microsoft.AspNetCore.SignalR;
using PondyConnect.Api.Hubs;
using PondyConnect.Application.Features.Support;

public sealed class CriticalTicketBroadcaster : ICriticalTicketBroadcaster
{
    private readonly IHubContext<AdminHub> _hubContext;

    public CriticalTicketBroadcaster(IHubContext<AdminHub> hubContext)
    {
        _hubContext = hubContext;
    }

    public Task BroadcastCriticalAsync(CriticalTicketNotification notification, CancellationToken cancellationToken)
    {
        return _hubContext.Clients.Group("critical-tickets")
            .SendAsync("CriticalTicketPushed", notification, cancellationToken);
    }
}

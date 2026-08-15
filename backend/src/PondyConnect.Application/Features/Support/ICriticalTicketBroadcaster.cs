namespace PondyConnect.Application.Features.Support;

public interface ICriticalTicketBroadcaster
{
    Task BroadcastCriticalAsync(CriticalTicketNotification notification, CancellationToken cancellationToken);
}

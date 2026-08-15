namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

public sealed class TicketMessage : BaseEntity
{
    public Guid TicketId { get; private set; }

    public MessageSenderRole SenderRole { get; private set; }

    public string MessageText { get; private set; } = string.Empty;

    private TicketMessage()
    {
    }

    public static TicketMessage Create(Guid ticketId, MessageSenderRole senderRole, string messageText)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(messageText);
        return new TicketMessage
        {
            TicketId = ticketId,
            SenderRole = senderRole,
            MessageText = messageText
        };
    }
}

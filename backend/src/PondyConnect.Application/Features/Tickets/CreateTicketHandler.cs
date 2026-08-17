namespace PondyConnect.Application.Features.Tickets;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed record CreateTicketCommand(
    string UserId,
    SupportTicketCategory Category,
    string Subject,
    string Description,
    Guid? OrderId = null,
    string? OrderType = null,
    string? PhotoUrl = null) : IRequest<CreateTicketResult>;

public sealed record CreateTicketResult(
    Guid TicketId,
    bool AutoResolved,
    decimal? CreditAmount,
    string? Message,
    string Status);

public sealed class CreateTicketHandler : IRequestHandler<CreateTicketCommand, CreateTicketResult>
{
    private readonly IApplicationDbContext _context;

    public CreateTicketHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<CreateTicketResult> Handle(CreateTicketCommand request, CancellationToken cancellationToken)
    {
        var ticket = DisputeTicket.Create(
            request.UserId,
            request.Category,
            request.Subject,
            request.Description,
            request.OrderId,
            request.OrderType,
            request.PhotoUrl);

        var resolution = await new AutoResolutionService(_context)
            .EvaluateAsync(ticket, cancellationToken);

        ticket.ApplyResolution(resolution.NewStatus, resolution.CreditAmount, resolution.Note);

        _context.DisputeTickets.Add(ticket);

        if (resolution.Resolved && resolution.CreditAmount > 0)
        {
            if (!Guid.TryParse(request.UserId, out var userGuid))
                throw new InvalidOperationException("Invalid user identity for wallet credit.");

            var wallet = await _context.UserWallets
                .FirstOrDefaultAsync(w => w.UserId == userGuid, cancellationToken);

            var isNewWallet = wallet is null;
            wallet ??= UserWallet.Create(userGuid, 0m, 0m);

            wallet.CreditReal(resolution.CreditAmount.Value);

            if (isNewWallet)
                _context.UserWallets.Add(wallet);
        }

        await _context.SaveChangesAsync(cancellationToken);

        return new CreateTicketResult(
            ticket.Id,
            resolution.Resolved,
            resolution.CreditAmount,
            resolution.Note,
            ticket.Status.ToString());
    }
}

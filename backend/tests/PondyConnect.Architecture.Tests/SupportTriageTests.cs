using PondyConnect.Application.Features.Support;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using Xunit;

namespace PondyConnect.Architecture.Tests;

public sealed class SupportTriageTests
{
    [Fact]
    public async Task MockLlm_DetectsAccident_AsCritical()
    {
        var llm = new MockLlmService();
        var result = await llm.GenerateResponseAsync("system", "I had an accident on my scooter", default);

        Assert.True(result.IsCritical);
        Assert.Contains("Critical", result.DetectedIntent);
    }

    [Fact]
    public async Task MockLlm_DetectsBrokenDown_AsCritical()
    {
        var llm = new MockLlmService();
        var result = await llm.GenerateResponseAsync("system", "My scooter broke down near Rock Beach", default);

        Assert.True(result.IsCritical);
    }

    [Fact]
    public async Task MockLlm_DetectsLockedOut_AsCritical()
    {
        var llm = new MockLlmService();
        var result = await llm.GenerateResponseAsync("system", "I'm locked out of my homestay", default);

        Assert.True(result.IsCritical);
    }

    [Fact]
    public async Task MockLlm_DetectsRefund_AsTransactional()
    {
        var llm = new MockLlmService();
        var result = await llm.GenerateResponseAsync("system", "I want a refund for my ride", default);

        Assert.False(result.IsCritical);
        Assert.Contains("Transactional", result.DetectedIntent);
    }

    [Fact]
    public async Task MockLlm_DefaultResponse_IsInfoTier()
    {
        var llm = new MockLlmService();
        var result = await llm.GenerateResponseAsync("system", "What are the best places to visit in Pondicherry?", default);

        Assert.False(result.IsCritical);
        Assert.Equal("Info", result.DetectedIntent);
    }

    [Fact]
    public void SupportTicket_Create_SetsDefaultValues()
    {
        var userId = Guid.NewGuid();
        var ticket = SupportTicket.Create(userId);

        Assert.Equal(userId, ticket.UserId);
        Assert.Equal(SupportTicketStatus.Open, ticket.Status);
        Assert.Equal(TicketPriority.Normal, ticket.Priority);
        Assert.Equal(TicketSource.InApp, ticket.Source);
    }

    [Fact]
    public void SupportTicket_Escalate_SetsCriticalAndEscalated()
    {
        var ticket = SupportTicket.Create(Guid.NewGuid());

        ticket.Escalate();

        Assert.Equal(TicketPriority.Critical, ticket.Priority);
        Assert.Equal(SupportTicketStatus.Escalated, ticket.Status);
    }

    [Fact]
    public void SupportTicket_MarkInProgress_OnlyWorksFromOpen()
    {
        var ticket = SupportTicket.Create(Guid.NewGuid());
        Assert.Equal(SupportTicketStatus.Open, ticket.Status);

        ticket.MarkInProgress();
        Assert.Equal(SupportTicketStatus.InProgress, ticket.Status);

        ticket.MarkInProgress();
        Assert.Equal(SupportTicketStatus.InProgress, ticket.Status);
    }

    [Fact]
    public void SupportTicket_Resolve_SetsResolvedAndTimestamp()
    {
        var ticket = SupportTicket.Create(Guid.NewGuid());

        ticket.Resolve();

        Assert.Equal(SupportTicketStatus.Resolved, ticket.Status);
        Assert.NotNull(ticket.ResolvedAt);
    }

    [Fact]
    public void SupportTicket_CreateSos_SetsCriticalAndSosSource()
    {
        var ticket = SupportTicket.Create(
            Guid.NewGuid(),
            TicketPriority.Critical,
            TicketSource.SOS,
            latitude: 11.93,
            longitude: 79.83,
            issueCategory: "Safety Concern");

        Assert.Equal(TicketPriority.Critical, ticket.Priority);
        Assert.Equal(TicketSource.SOS, ticket.Source);
        Assert.Equal("Safety Concern", ticket.IssueCategory);
        Assert.Equal(11.93, ticket.Latitude);
        Assert.Equal(79.83, ticket.Longitude);
    }

    [Fact]
    public void TicketMessage_Create_SetsSenderRoleAndText()
    {
        var ticketId = Guid.NewGuid();
        var message = TicketMessage.Create(ticketId, MessageSenderRole.AI, "Hello, how can I help?");

        Assert.Equal(ticketId, message.TicketId);
        Assert.Equal(MessageSenderRole.AI, message.SenderRole);
        Assert.Equal("Hello, how can I help?", message.MessageText);
    }

    [Fact]
    public void TicketMessage_Create_ThrowsOnEmptyText()
    {
        Assert.Throws<ArgumentException>(() =>
            TicketMessage.Create(Guid.NewGuid(), MessageSenderRole.User, ""));
    }
}

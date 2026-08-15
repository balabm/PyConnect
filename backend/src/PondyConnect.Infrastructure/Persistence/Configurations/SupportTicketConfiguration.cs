namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class SupportTicketConfiguration : IEntityTypeConfiguration<SupportTicket>
{
    public void Configure(EntityTypeBuilder<SupportTicket> builder)
    {
        builder.ToTable("support_tickets");

        builder.HasKey(t => t.Id);

        builder.Property(t => t.UserId).IsRequired();
        builder.HasIndex(t => t.UserId);

        builder.Property(t => t.Status)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(t => t.Priority)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(t => t.Source)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(t => t.IssueCategory).HasMaxLength(100);

        builder.Property(t => t.CreatedAt).HasColumnType("timestamptz");
        builder.Property(t => t.UpdatedAt).HasColumnType("timestamptz");
        builder.Property(t => t.ResolvedAt).HasColumnType("timestamptz");
        builder.Property(t => t.AcknowledgedAt).HasColumnType("timestamptz");

        builder.HasIndex(t => t.Status);
        builder.HasIndex(t => t.Priority);
    }
}

public sealed class TicketMessageConfiguration : IEntityTypeConfiguration<TicketMessage>
{
    public void Configure(EntityTypeBuilder<TicketMessage> builder)
    {
        builder.ToTable("ticket_messages");

        builder.HasKey(m => m.Id);

        builder.Property(m => m.TicketId).IsRequired();
        builder.HasIndex(m => m.TicketId);

        builder.Property(m => m.SenderRole)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(m => m.MessageText).IsRequired().HasMaxLength(4000);

        builder.Property(m => m.CreatedAt).HasColumnType("timestamptz");

        builder.HasOne<SupportTicket>()
            .WithMany()
            .HasForeignKey(m => m.TicketId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

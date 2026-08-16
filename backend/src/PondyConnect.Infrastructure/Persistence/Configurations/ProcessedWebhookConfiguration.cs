namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class ProcessedWebhookConfiguration : IEntityTypeConfiguration<ProcessedWebhook>
{
    public void Configure(EntityTypeBuilder<ProcessedWebhook> builder)
    {
        builder.ToTable("processed_webhooks");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.EventId)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(e => e.EventType)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(e => e.ProcessedAt)
            .HasColumnType("timestamptz");

        builder.Property(e => e.Payload)
            .HasColumnType("jsonb");

        // Unique index on EventId — a duplicate insert (webhook replay)
        // violates this constraint and is caught by the idempotency check.
        builder.HasIndex(e => e.EventId)
            .IsUnique();

        builder.Property(e => e.CreatedAt)
            .HasColumnType("timestamptz");
    }
}

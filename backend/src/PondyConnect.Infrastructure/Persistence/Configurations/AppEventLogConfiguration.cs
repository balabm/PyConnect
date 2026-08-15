namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class AppEventLogConfiguration : IEntityTypeConfiguration<AppEventLog>
{
    public void Configure(EntityTypeBuilder<AppEventLog> builder)
    {
        builder.ToTable("app_event_logs");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.SessionId)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(e => e.EventName)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(e => e.EventPayload)
            .HasColumnType("jsonb");

        builder.Property(e => e.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasIndex(e => e.EventName);
        builder.HasIndex(e => e.CreatedAt);
    }
}

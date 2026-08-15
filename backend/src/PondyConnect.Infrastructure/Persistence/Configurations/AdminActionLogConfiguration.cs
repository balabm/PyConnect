namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class AdminActionLogConfiguration : IEntityTypeConfiguration<AdminActionLog>
{
    public void Configure(EntityTypeBuilder<AdminActionLog> builder)
    {
        builder.ToTable("admin_action_logs");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.AdminUserId)
            .IsRequired();

        builder.Property(e => e.ActionType)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(e => e.EntityType)
            .HasMaxLength(100);

        builder.Property(e => e.Payload)
            .HasColumnType("jsonb");

        builder.Property(e => e.IpAddress)
            .HasMaxLength(45);

        builder.Property(e => e.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasIndex(e => e.AdminUserId);
        builder.HasIndex(e => e.ActionType);
        builder.HasIndex(e => e.CreatedAt);
        builder.HasIndex(e => new { e.EntityType, e.EntityId });
    }
}

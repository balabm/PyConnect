namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class ConsumerFlagConfiguration : IEntityTypeConfiguration<ConsumerFlag>
{
    public void Configure(EntityTypeBuilder<ConsumerFlag> builder)
    {
        builder.ToTable("consumer_flags");

        builder.HasKey(f => f.Id);

        builder.Property(f => f.ConsumerId).IsRequired().HasMaxLength(100);
        builder.Property(f => f.FlagType).HasConversion<int>().IsRequired();
        builder.Property(f => f.Reason).IsRequired().HasMaxLength(500);
        builder.Property(f => f.ShadowBanned).IsRequired();
        builder.Property(f => f.CodRestricted).IsRequired();
        builder.Property(f => f.ExpiresAt).HasColumnType("timestamptz");

        // IsActive is a computed read-only flag derived from ExpiresAt —
        // it has no backing field and must not be mapped.
        builder.Ignore(f => f.IsActive);
        builder.Property(f => f.CreatedAt).HasColumnType("timestamptz");
        builder.Property(f => f.UpdatedAt).HasColumnType("timestamptz");

        builder.HasIndex(f => f.ConsumerId);
        builder.HasIndex(f => f.ExpiresAt);
    }
}

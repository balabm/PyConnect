namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class BundleItemConfiguration : IEntityTypeConfiguration<BundleItem>
{
    public void Configure(EntityTypeBuilder<BundleItem> builder)
    {
        builder.ToTable("bundle_items");

        builder.HasKey(i => i.Id);

        builder.Property(i => i.BundleBookingId)
            .IsRequired();

        builder.Property(i => i.ServiceName)
            .IsRequired()
            .HasMaxLength(160);

        builder.Property(i => i.ServiceReferenceId)
            .HasMaxLength(64);

        builder.Property(i => i.ExperienceCategory)
            .HasConversion<int>();

        builder.Property(i => i.OriginalPrice)
            .HasPrecision(10, 2)
            .IsRequired();

        builder.Property(i => i.IsRedeemed)
            .IsRequired();

        builder.Property(i => i.RedeemedAt)
            .HasColumnType("timestamptz");

        builder.Property(i => i.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasIndex(i => i.BundleBookingId);
        builder.HasIndex(i => i.ServiceReferenceId);
        builder.HasIndex(i => i.IsRedeemed);
    }
}
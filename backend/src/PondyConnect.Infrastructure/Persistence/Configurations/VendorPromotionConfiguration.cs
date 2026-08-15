namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class VendorPromotionConfiguration : IEntityTypeConfiguration<VendorPromotion>
{
    public void Configure(EntityTypeBuilder<VendorPromotion> builder)
    {
        builder.ToTable("vendor_promotions");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.VendorId)
            .IsRequired();

        builder.Property(p => p.PromoType)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(p => p.Title)
            .IsRequired()
            .HasMaxLength(160);

        builder.Property(p => p.Description)
            .HasMaxLength(1000);

        builder.Property(p => p.TargetLatitude)
            .HasPrecision(9, 6);

        builder.Property(p => p.TargetLongitude)
            .HasPrecision(9, 6);

        builder.Property(p => p.TargetRadiusKm)
            .HasPrecision(6, 2);

        builder.Property(p => p.Cost)
            .HasPrecision(10, 2)
            .IsRequired();

        builder.Property(p => p.DiscountPercentage)
            .HasPrecision(5, 2);

        builder.Property(p => p.StartsAt)
            .HasColumnType("timestamptz")
            .IsRequired();

        builder.Property(p => p.ExpiresAt)
            .HasColumnType("timestamptz")
            .IsRequired();

        builder.Property(p => p.IsActive)
            .IsRequired();

        builder.Property(p => p.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasOne(p => p.Vendor)
            .WithMany()
            .HasForeignKey(p => p.VendorId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(p => p.VendorId);
        builder.HasIndex(p => p.PromoType);
        builder.HasIndex(p => p.IsActive);
        builder.HasIndex(p => p.ExpiresAt);
        builder.HasIndex(p => new { p.VendorId, p.IsActive });
    }
}
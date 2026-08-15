namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class VendorConfiguration : IEntityTypeConfiguration<Vendor>
{
    public void Configure(EntityTypeBuilder<Vendor> builder)
    {
        builder.ToTable("vendors");

        builder.HasKey(v => v.Id);

        builder.Property(v => v.Name)
            .IsRequired()
            .HasMaxLength(160);

        builder.Property(v => v.ContactPhone)
            .HasMaxLength(15);

        builder.Property(v => v.MerchantReference)
            .HasMaxLength(64);

        builder.Property(v => v.Category)
            .HasConversion<string>()
            .HasMaxLength(20)
            .HasDefaultValue(VendorCategory.LuggageCloak);

        builder.Property(v => v.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasIndex(v => v.Category);
        builder.HasIndex(v => v.IsApproved);

        builder.Property(v => v.SaaSTier)
            .HasConversion<string>()
            .HasMaxLength(20)
            .HasDefaultValue(SaaSTier.Free);

        builder.Property(v => v.SaaSPlanExpiry)
            .HasColumnType("timestamptz");

        builder.Property(v => v.MonthlyFee)
            .HasPrecision(10, 2)
            .HasDefaultValue(0m);

        builder.Property(v => v.CreditBalance)
            .HasPrecision(18, 2)
            .HasDefaultValue(0m);

        // Restaurant-specific metadata
        builder.Property(v => v.CuisineType)
            .HasMaxLength(50);

        builder.Property(v => v.Rating)
            .HasDefaultValue(null);

        builder.Property(v => v.ImageUrl)
            .HasMaxLength(500);

        builder.Property(v => v.Description)
            .HasMaxLength(500);

        builder.Property(v => v.DeliveryFee)
            .HasPrecision(10, 2);

        builder.Property(v => v.PrepTimeMinutes);
    }
}
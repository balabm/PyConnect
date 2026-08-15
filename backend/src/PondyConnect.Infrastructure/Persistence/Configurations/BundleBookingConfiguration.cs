namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class BundleBookingConfiguration : IEntityTypeConfiguration<BundleBooking>
{
    public void Configure(EntityTypeBuilder<BundleBooking> builder)
    {
        builder.ToTable("bundle_bookings");

        builder.HasKey(b => b.Id);

        builder.Property(b => b.UserId)
            .IsRequired();

        builder.Property(b => b.Name)
            .IsRequired()
            .HasMaxLength(160);

        builder.Property(b => b.Description)
            .HasMaxLength(1000);

        builder.Property(b => b.TotalPrice)
            .HasPrecision(10, 2)
            .IsRequired();

        builder.Property(b => b.DiscountedPrice)
            .HasPrecision(10, 2)
            .IsRequired();

        builder.Property(b => b.Status)
            .HasConversion<int>()
            .IsRequired();

        builder.Property(b => b.ExpiresAt)
            .HasColumnType("timestamptz");

        builder.Property(b => b.PassToken)
            .HasMaxLength(256);

        builder.Property(b => b.PassType)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(b => b.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasMany(b => b.Items)
            .WithOne(i => i.BundleBooking)
            .HasForeignKey(i => i.BundleBookingId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(b => b.UserId);
        builder.HasIndex(b => b.Status);
        builder.HasIndex(b => b.ExpiresAt);
    }
}
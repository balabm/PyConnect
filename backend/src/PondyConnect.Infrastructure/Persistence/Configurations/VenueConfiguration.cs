namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.ValueObjects;

public sealed class VenueConfiguration : IEntityTypeConfiguration<Venue>
{
    public void Configure(EntityTypeBuilder<Venue> builder)
    {
        builder.ToTable("venues");

        builder.HasKey(v => v.Id);

        builder.Property(v => v.Name)
            .IsRequired()
            .HasMaxLength(160);

        builder.Property(v => v.Category)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.OwnsOne(v => v.Location, location =>
        {
            location.Property(l => l.Latitude).HasColumnName("location_lat").HasColumnType("double precision");
            location.Property(l => l.Longitude).HasColumnName("location_lng").HasColumnType("double precision");
        });

        builder.Property(v => v.Address)
            .HasMaxLength(300);

        builder.HasOne<Vendor>()
            .WithMany()
            .HasForeignKey(v => v.VendorId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasMany(v => v.Availability)
            .WithOne()
            .HasForeignKey(a => a.VenueId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Property(v => v.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasIndex(v => v.Category);

        builder.Property(v => v.IsPriorityPingActive)
            .HasDefaultValue(false);

        builder.Property(v => v.PriorityPingExpiry)
            .HasColumnType("timestamptz");

        builder.HasIndex(v => v.IsPriorityPingActive);

        builder.Property(v => v.CheckedInCount)
            .HasDefaultValue(0);
    }
}

public sealed class VenueAvailabilityConfiguration : IEntityTypeConfiguration<VenueAvailability>
{
    public void Configure(EntityTypeBuilder<VenueAvailability> builder)
    {
        builder.ToTable("venue_availability");

        builder.HasKey(a => a.Id);

        builder.Property(a => a.DayOfWeek)
            .HasConversion<string>()
            .HasMaxLength(12);

        builder.Property(a => a.OpensAt)
            .HasColumnType("time");

        builder.Property(a => a.ClosesAt)
            .HasColumnType("time");

        builder.Property(a => a.CreatedAt)
            .HasColumnType("timestamptz");
    }
}
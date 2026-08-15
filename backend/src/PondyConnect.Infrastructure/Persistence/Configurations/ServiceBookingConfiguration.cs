namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class ServiceBookingConfiguration : IEntityTypeConfiguration<ServiceBooking>
{
    public void Configure(EntityTypeBuilder<ServiceBooking> builder)
    {
        builder.ToTable("service_bookings");

        builder.HasKey(b => b.Id);

        builder.Property(b => b.ServiceType)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(b => b.Status)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(b => b.PaymentStatus)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(b => b.TotalAmount)
            .HasColumnType("numeric(14,2)");

        builder.Property(b => b.Currency)
            .HasMaxLength(4)
            .HasDefaultValue("INR");

        builder.Property(b => b.ScheduledFor)
            .HasColumnType("timestamptz");

        builder.Property(b => b.CompletedAt)
            .HasColumnType("timestamptz");

        builder.Property(b => b.PaymentReference)
            .HasMaxLength(64);

        builder.Property(b => b.Notes)
            .HasMaxLength(500);

        builder.Property(b => b.CheckInDate)
            .HasColumnType("date");

        builder.Property(b => b.CheckOutDate)
            .HasColumnType("date");

        builder.Property(b => b.HomestayId);

        builder.HasIndex(b => b.HomestayId);

        builder.Property(b => b.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasOne<User>()
            .WithMany()
            .HasForeignKey(b => b.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<Vendor>()
            .WithMany()
            .HasForeignKey(b => b.VendorId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasMany(b => b.Items)
            .WithOne()
            .HasForeignKey(i => i.ServiceBookingId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Property(b => b.PassToken)
            .HasMaxLength(128);

        builder.HasIndex(b => b.PassToken)
            .IsUnique();

        builder.HasIndex(b => b.VenueId);

        builder.HasIndex(b => b.UserId);
        builder.HasIndex(b => b.VendorId);
        builder.HasIndex(b => new { b.ScheduledFor, b.ServiceType });
    }
}

public sealed class BookingItemConfiguration : IEntityTypeConfiguration<BookingItem>
{
    public void Configure(EntityTypeBuilder<BookingItem> builder)
    {
        builder.ToTable("booking_items");

        builder.HasKey(i => i.Id);

        builder.Property(i => i.Description)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(i => i.UnitPrice)
            .HasColumnType("numeric(14,2)");

        builder.Property(i => i.CreatedAt)
            .HasColumnType("timestamptz");
    }
}
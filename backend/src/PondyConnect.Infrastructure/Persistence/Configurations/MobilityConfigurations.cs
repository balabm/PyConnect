namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.ValueObjects;

public sealed class TransitHubConfiguration : IEntityTypeConfiguration<TransitHub>
{
    public void Configure(EntityTypeBuilder<TransitHub> builder)
    {
        builder.ToTable("transit_hubs");

        builder.HasKey(h => h.Id);

        builder.Property(h => h.Name)
            .IsRequired()
            .HasMaxLength(160);

        builder.Property(h => h.Kind)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.OwnsOne(h => h.Location, location =>
        {
            location.Property(l => l.Latitude).HasColumnName("location_lat").HasColumnType("double precision");
            location.Property(l => l.Longitude).HasColumnName("location_lng").HasColumnType("double precision");
        });

        builder.Property(h => h.Address)
            .HasMaxLength(300);

        builder.Property(h => h.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasIndex(h => h.Kind);
    }
}

public sealed class TransitTripConfiguration : IEntityTypeConfiguration<TransitTrip>
{
    public void Configure(EntityTypeBuilder<TransitTrip> builder)
    {
        builder.ToTable("transit_trips");

        builder.HasKey(t => t.Id);

        builder.Property(t => t.UserId).IsRequired();

        builder.Property(t => t.HubId).IsRequired();

        builder.Property(t => t.ArrivalFrom)
            .IsRequired()
            .HasMaxLength(120);

        builder.Property(t => t.ArrivalMode)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(t => t.ArrivalAt)
            .HasColumnType("timestamptz");

        builder.Property(t => t.PartySize).IsRequired();

        builder.Property(t => t.DropOffLocation)
            .HasMaxLength(200);

        builder.Property(t => t.Status)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(t => t.Price)
            .HasColumnType("numeric(12,2)");

        builder.Property(t => t.PaymentStatus)
            .HasConversion<string>()
            .HasMaxLength(12);

        builder.Property(t => t.PaymentReference)
            .HasMaxLength(100);

        builder.Property(t => t.Notes)
            .HasMaxLength(500);

        builder.Property(t => t.DriverName)
            .HasMaxLength(120);

        builder.Property(t => t.VehiclePlate)
            .HasMaxLength(20);

        builder.Property(t => t.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasOne(t => t.Hub)
            .WithMany()
            .HasForeignKey(t => t.HubId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(t => t.Vendor)
            .WithMany()
            .HasForeignKey(t => t.VendorId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(t => t.UserId);
        builder.HasIndex(t => t.HubId);
        builder.HasIndex(t => t.Status);
    }
}

public sealed class LuggageDropOffConfiguration : IEntityTypeConfiguration<LuggageDropOff>
{
    public void Configure(EntityTypeBuilder<LuggageDropOff> builder)
    {
        builder.ToTable("luggage_drop_offs");

        builder.HasKey(l => l.Id);

        builder.Property(l => l.UserId).IsRequired();

        builder.Property(l => l.VendorId).IsRequired();

        builder.Property(l => l.ScheduledFor)
            .HasColumnType("timestamptz");

        builder.Property(l => l.DroppedAt)
            .HasColumnType("timestamptz");

        builder.Property(l => l.PickedUpAt)
            .HasColumnType("timestamptz");

        builder.Property(l => l.BagCount).IsRequired();

        builder.Property(l => l.RatePerHour)
            .HasColumnType("numeric(12,2)");

        builder.Property(l => l.TotalAmount)
            .HasColumnType("numeric(12,2)");

        builder.Property(l => l.Status)
            .HasConversion<string>()
            .HasMaxLength(12);

        builder.Property(l => l.PaymentStatus)
            .HasConversion<string>()
            .HasMaxLength(12);

        builder.Property(l => l.PaymentReference)
            .HasMaxLength(100);

        builder.Property(l => l.Notes)
            .HasMaxLength(500);

        builder.Property(l => l.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasOne(l => l.Vendor)
            .WithMany()
            .HasForeignKey(l => l.VendorId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(l => l.UserId);
        builder.HasIndex(l => l.VendorId);
        builder.HasIndex(l => l.Status);
    }
}

public sealed class ScooterRentalConfiguration : IEntityTypeConfiguration<ScooterRental>
{
    public void Configure(EntityTypeBuilder<ScooterRental> builder)
    {
        builder.ToTable("scooter_rentals");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.UserId).IsRequired();

        builder.Property(r => r.VendorId).IsRequired();

        builder.Property(r => r.VehicleName)
            .IsRequired()
            .HasMaxLength(80);

        builder.Property(r => r.VehiclePlate)
            .HasMaxLength(20);

        builder.Property(r => r.RentalStart)
            .HasColumnType("timestamptz");

        builder.Property(r => r.RentalEnd)
            .HasColumnType("timestamptz");

        builder.Property(r => r.RatePerHour)
            .HasColumnType("numeric(12,2)");

        builder.Property(r => r.TotalAmount)
            .HasColumnType("numeric(12,2)");

        builder.Property(r => r.Status)
            .HasConversion<string>()
            .HasMaxLength(12);

        builder.Property(r => r.PaymentStatus)
            .HasConversion<string>()
            .HasMaxLength(12);

        builder.Property(r => r.PaymentReference)
            .HasMaxLength(100);

        builder.Property(r => r.Notes)
            .HasMaxLength(500);

        builder.Property(r => r.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasOne(r => r.Vendor)
            .WithMany()
            .HasForeignKey(r => r.VendorId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(r => r.UserId);
        builder.HasIndex(r => r.VendorId);
        builder.HasIndex(r => r.Status);
    }
}

public sealed class PaymentConfiguration : IEntityTypeConfiguration<Payment>
{
    public void Configure(EntityTypeBuilder<Payment> builder)
    {
        builder.ToTable("payments");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.ServiceBookingId).IsRequired(false);
        builder.Property(p => p.TransitTripId).IsRequired(false);
        builder.Property(p => p.LuggageDropOffId).IsRequired(false);
        builder.Property(p => p.ScooterRentalId).IsRequired(false);
        builder.Property(p => p.FoodOrderId).IsRequired(false);

        builder.Property(p => p.Amount)
            .HasColumnType("numeric(12,2)")
            .IsRequired();

        builder.Property(p => p.Currency)
            .IsRequired()
            .HasMaxLength(3);

        builder.Property(p => p.Provider)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(p => p.Method)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(p => p.ProviderOrderId)
            .HasMaxLength(100);

        builder.Property(p => p.ProviderPaymentId)
            .HasMaxLength(100);

        builder.Property(p => p.Status)
            .HasConversion<string>()
            .HasMaxLength(12);

        builder.Property(p => p.FailureReason)
            .HasMaxLength(500);

        builder.Property(p => p.CreatedAt)
            .HasColumnType("timestamptz");

        builder.HasIndex(p => p.ServiceBookingId);
        builder.HasIndex(p => p.TransitTripId);
        builder.HasIndex(p => p.LuggageDropOffId);
        builder.HasIndex(p => p.ScooterRentalId);
        builder.HasIndex(p => p.FoodOrderId);
        builder.HasIndex(p => p.ProviderOrderId).IsUnique();
        builder.HasIndex(p => p.Status);
    }
}
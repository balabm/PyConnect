namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class EquipmentItemConfiguration : IEntityTypeConfiguration<EquipmentItem>
{
    public void Configure(EntityTypeBuilder<EquipmentItem> builder)
    {
        builder.ToTable("equipment_items");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.VendorId).IsRequired();

        builder.Property(e => e.Name)
            .IsRequired()
            .HasMaxLength(120);

        builder.Property(e => e.Description)
            .HasMaxLength(500);

        builder.Property(e => e.DailyRentalPrice)
            .HasColumnType("numeric(12,2)")
            .IsRequired();

        builder.Property(e => e.SecurityDepositAmount)
            .HasColumnType("numeric(12,2)")
            .IsRequired();

        builder.Property(e => e.TotalUnits).IsRequired();

        builder.Property(e => e.AvailableUnits).IsRequired();

        builder.Property(e => e.Category)
            .IsRequired()
            .HasMaxLength(30);

        builder.Property(e => e.ImageUrl).HasMaxLength(500);

        builder.Property(e => e.IsAvailable).IsRequired();

        builder.Property(e => e.CreatedAt).HasColumnType("timestamptz");
        builder.Property(e => e.UpdatedAt).HasColumnType("timestamptz");

        builder.HasIndex(e => e.VendorId);
        builder.HasIndex(e => e.IsAvailable);
    }
}

public sealed class EquipmentRentalConfiguration : IEntityTypeConfiguration<EquipmentRental>
{
    public void Configure(EntityTypeBuilder<EquipmentRental> builder)
    {
        builder.ToTable("equipment_rentals");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.UserId).IsRequired();
        builder.Property(r => r.VendorId).IsRequired();
        builder.Property(r => r.EquipmentItemId).IsRequired();
        builder.Property(r => r.UnitsBooked).IsRequired();

        builder.Property(r => r.RentalStart).HasColumnType("timestamptz").IsRequired();
        builder.Property(r => r.RentalEnd).HasColumnType("timestamptz").IsRequired();

        builder.Property(r => r.DailyRate).HasColumnType("numeric(12,2)").IsRequired();
        builder.Property(r => r.TotalAmount).HasColumnType("numeric(12,2)").IsRequired();

        builder.Property(r => r.Status)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(r => r.PaymentStatus)
            .HasConversion<string>()
            .HasMaxLength(12)
            .IsRequired();

        builder.Property(r => r.PaymentReference).HasMaxLength(100);
        builder.Property(r => r.SecurityDeposit).HasColumnType("numeric(12,2)");
        builder.Property(r => r.DepositPaymentReference).HasMaxLength(100);
        builder.Property(r => r.DepositPenalty).HasColumnType("numeric(12,2)");
        builder.Property(r => r.DepositRefunded).HasColumnType("numeric(12,2)");
        builder.Property(r => r.ConditionPhotosJson).HasColumnType("jsonb");
        builder.Property(r => r.ReturnConditionPhotosJson).HasColumnType("jsonb");
        builder.Property(r => r.ActualReturnAt).HasColumnType("timestamptz");
        builder.Property(r => r.DeliveryAddress).HasMaxLength(500);
        builder.Property(r => r.Notes).HasMaxLength(500);

        builder.Property(r => r.CreatedAt).HasColumnType("timestamptz");
        builder.Property(r => r.UpdatedAt).HasColumnType("timestamptz");

        builder.HasIndex(r => r.VendorId);
        builder.HasIndex(r => r.UserId);
        builder.HasIndex(r => r.Status);
        builder.HasIndex(r => new { r.VendorId, r.Status });
    }
}

public sealed class P2pEventConfiguration : IEntityTypeConfiguration<P2pEvent>
{
    public void Configure(EntityTypeBuilder<P2pEvent> builder)
    {
        builder.ToTable("p2p_events");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.HostUserId).IsRequired();

        builder.Property(e => e.Title)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(e => e.Slug)
            .IsRequired()
            .HasMaxLength(120);

        builder.Property(e => e.Description).HasMaxLength(2000);
        builder.Property(e => e.WhatsOffered).HasMaxLength(500);
        builder.Property(e => e.Address).HasMaxLength(500);

        builder.Property(e => e.StartsAt).HasColumnType("timestamptz").IsRequired();
        builder.Property(e => e.EndsAt).HasColumnType("timestamptz").IsRequired();

        builder.Property(e => e.EntryPrice).HasColumnType("numeric(12,2)").IsRequired();
        builder.Property(e => e.CapacityLimit).IsRequired();
        builder.Property(e => e.TicketsSold).IsRequired();

        builder.Property(e => e.Status)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(e => e.ImageUrl).HasMaxLength(500);
        builder.Property(e => e.PlatformFeePercent).HasPrecision(5, 2);

        builder.Property(e => e.CreatedAt).HasColumnType("timestamptz");
        builder.Property(e => e.UpdatedAt).HasColumnType("timestamptz");

        builder.OwnsOne(e => e.Location, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("location_lat").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("location_lng").HasColumnType("double precision");
        });

        builder.HasIndex(e => e.Slug).IsUnique();
        builder.HasIndex(e => e.HostUserId);
        builder.HasIndex(e => e.Status);
    }
}

public sealed class P2pEventTicketConfiguration : IEntityTypeConfiguration<P2pEventTicket>
{
    public void Configure(EntityTypeBuilder<P2pEventTicket> builder)
    {
        builder.ToTable("p2p_event_tickets");

        builder.HasKey(t => t.Id);

        builder.Property(t => t.P2pEventId).IsRequired();
        builder.Property(t => t.BuyerUserId).IsRequired();

        builder.Property(t => t.PricePaid).HasColumnType("numeric(12,2)").IsRequired();
        builder.Property(t => t.PlatformFee).HasColumnType("numeric(12,2)").IsRequired();
        builder.Property(t => t.HostPayout).HasColumnType("numeric(12,2)").IsRequired();

        builder.Property(t => t.PaymentStatus)
            .HasConversion<string>()
            .HasMaxLength(12)
            .IsRequired();

        builder.Property(t => t.PaymentReference).HasMaxLength(100);
        builder.Property(t => t.PassToken).HasMaxLength(100);
        builder.Property(t => t.Status).HasMaxLength(20).IsRequired();

        builder.Property(t => t.CheckedInAt).HasColumnType("timestamptz");
        builder.Property(t => t.PurchasedAt).HasColumnType("timestamptz").IsRequired();

        builder.Property(t => t.CreatedAt).HasColumnType("timestamptz");
        builder.Property(t => t.UpdatedAt).HasColumnType("timestamptz");

        builder.HasIndex(t => t.PassToken).IsUnique().HasFilter("\"PassToken\" IS NOT NULL");
        builder.HasIndex(t => new { t.P2pEventId, t.BuyerUserId });
        builder.HasIndex(t => t.P2pEventId);
    }
}

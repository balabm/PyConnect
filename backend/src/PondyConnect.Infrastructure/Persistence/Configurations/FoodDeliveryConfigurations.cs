namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.ValueObjects;

public sealed class FoodOrderConfiguration : IEntityTypeConfiguration<FoodOrder>
{
    public void Configure(EntityTypeBuilder<FoodOrder> builder)
    {
        builder.ToTable("food_orders");

        builder.HasKey(o => o.Id);

        builder.Property(o => o.UserId).IsRequired();
        builder.Property(o => o.VendorId).IsRequired();

        builder.Property(o => o.Status)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(o => o.SubTotal).HasPrecision(10, 2);
        builder.Property(o => o.VendorPayout).HasPrecision(10, 2);
        builder.Property(o => o.DeliveryFee).HasPrecision(10, 2);
        builder.Property(o => o.LateNightDriverBonus).HasPrecision(10, 2);
        builder.Property(o => o.PlatformFee).HasPrecision(10, 2);
        builder.Property(o => o.Taxes).HasPrecision(10, 2);
        builder.Property(o => o.TotalAmount).HasPrecision(10, 2);

        builder.Property(o => o.Currency).HasMaxLength(3).IsRequired();
        builder.Property(o => o.DeliveryAddress).HasMaxLength(500).IsRequired();

        builder.OwnsOne(o => o.DeliveryLocation, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("delivery_lat").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("delivery_lng").HasColumnType("double precision");
        });

        builder.Property(o => o.PaymentMethod)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(o => o.PaymentStatus)
            .HasConversion<string>()
            .HasMaxLength(20);

        builder.Property(o => o.PlacedAt).HasColumnType("timestamptz");
        builder.Property(o => o.DeliveredAt).HasColumnType("timestamptz");
        builder.Property(o => o.Notes).HasMaxLength(500);

        builder.HasIndex(o => o.UserId);
        builder.HasIndex(o => o.VendorId);
        builder.HasIndex(o => o.Status);
    }
}

public sealed class FoodOrderItemConfiguration : IEntityTypeConfiguration<FoodOrderItem>
{
    public void Configure(EntityTypeBuilder<FoodOrderItem> builder)
    {
        builder.ToTable("food_order_items");

        builder.HasKey(i => i.Id);

        builder.Property(i => i.FoodOrderId).IsRequired();
        builder.Property(i => i.Name).HasMaxLength(200).IsRequired();
        builder.Property(i => i.Quantity).IsRequired();
        builder.Property(i => i.UnitPrice).HasPrecision(10, 2);
        builder.Property(i => i.SpecialInstructions).HasMaxLength(500);

        builder.HasOne<FoodOrder>()
            .WithMany(o => o.Items)
            .HasForeignKey(i => i.FoodOrderId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(i => i.FoodOrderId);
    }
}

public sealed class MenuItemConfiguration : IEntityTypeConfiguration<MenuItem>
{
    public void Configure(EntityTypeBuilder<MenuItem> builder)
    {
        builder.ToTable("menu_items");

        builder.HasKey(m => m.Id);

        builder.Property(m => m.VendorId).IsRequired();
        builder.Property(m => m.Name).HasMaxLength(200).IsRequired();
        builder.Property(m => m.Description).HasMaxLength(1000);
        builder.Property(m => m.Price).HasPrecision(10, 2);
        builder.Property(m => m.Category).HasMaxLength(50).IsRequired();
        builder.Property(m => m.ImageUrl).HasMaxLength(500);

        builder.HasIndex(m => new { m.VendorId, m.IsAvailable });
        builder.HasIndex(m => m.IsLateNight);
    }
}

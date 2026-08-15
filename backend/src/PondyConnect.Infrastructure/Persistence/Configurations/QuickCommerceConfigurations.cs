namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.ValueObjects;

public sealed class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> builder)
    {
        builder.ToTable("products");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.Name).HasMaxLength(200).IsRequired();
        builder.Property(p => p.Description).HasMaxLength(1000);
        builder.Property(p => p.Price).HasPrecision(10, 2);
        builder.Property(p => p.Category).HasConversion<string>().HasMaxLength(30);
        builder.Property(p => p.SubCategory).HasMaxLength(50).IsRequired();
        builder.Property(p => p.Brand).HasMaxLength(100);
        builder.Property(p => p.ImageUrl).HasMaxLength(500);

        builder.HasIndex(p => new { p.Category, p.IsAvailable });
        builder.HasIndex(p => p.IsLateNightEssential);
        builder.HasIndex(p => p.VendorId);
    }
}

public sealed class ProductOrderConfiguration : IEntityTypeConfiguration<ProductOrder>
{
    public void Configure(EntityTypeBuilder<ProductOrder> builder)
    {
        builder.ToTable("product_orders");

        builder.HasKey(o => o.Id);

        builder.Property(o => o.UserId).IsRequired();
        builder.Property(o => o.Status).HasConversion<string>().HasMaxLength(20);
        builder.Property(o => o.SubTotal).HasPrecision(10, 2);
        builder.Property(o => o.DeliveryFee).HasPrecision(10, 2);
        builder.Property(o => o.TotalAmount).HasPrecision(10, 2);
        builder.Property(o => o.Currency).HasMaxLength(3).IsRequired();
        builder.Property(o => o.DeliveryAddress).HasMaxLength(500).IsRequired();

        builder.OwnsOne(o => o.DeliveryLocation, loc =>
        {
            loc.Property(l => l.Latitude).HasColumnName("delivery_lat").HasColumnType("double precision");
            loc.Property(l => l.Longitude).HasColumnName("delivery_lng").HasColumnType("double precision");
        });

        builder.Property(o => o.PaymentStatus).HasConversion<string>().HasMaxLength(20);
        builder.Property(o => o.PlacedAt).HasColumnType("timestamptz");
        builder.Property(o => o.DeliveredAt).HasColumnType("timestamptz");

        builder.HasIndex(o => o.UserId);
        builder.HasIndex(o => o.VendorId);
    }
}

public sealed class ProductOrderItemConfiguration : IEntityTypeConfiguration<ProductOrderItem>
{
    public void Configure(EntityTypeBuilder<ProductOrderItem> builder)
    {
        builder.ToTable("product_order_items");

        builder.HasKey(i => i.Id);

        builder.Property(i => i.ProductOrderId).IsRequired();
        builder.Property(i => i.Name).HasMaxLength(200).IsRequired();
        builder.Property(i => i.Quantity).IsRequired();
        builder.Property(i => i.UnitPrice).HasPrecision(10, 2);

        builder.HasOne<ProductOrder>()
            .WithMany(o => o.Items)
            .HasForeignKey(i => i.ProductOrderId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(i => i.ProductOrderId);
    }
}

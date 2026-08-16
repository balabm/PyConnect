namespace PondyConnect.Infrastructure.Persistence.Configurations;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using PondyConnect.Domain.Entities;

public sealed class ReviewConfiguration : IEntityTypeConfiguration<Review>
{
    public void Configure(EntityTypeBuilder<Review> builder)
    {
        builder.ToTable("reviews");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.UserId).IsRequired();
        builder.Property(r => r.Rating).IsRequired();
        builder.Property(r => r.Feedback).HasMaxLength(500);
        builder.Property(r => r.TipAmount).HasPrecision(12, 2);
        builder.Property(r => r.TipReference).HasMaxLength(100);
        builder.Property(r => r.CreatedAt).HasColumnType("timestamptz");

        builder.HasIndex(r => r.DriverId);
        builder.HasIndex(r => r.VendorId);
        builder.HasIndex(r => r.RideId);
        builder.HasIndex(r => r.OrderId);
        builder.HasIndex(r => r.UserId);
    }
}
